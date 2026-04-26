package com.example.gravil

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import engine.Engine
import engine.Key
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.charset.Charset
import java.util.zip.GZIPInputStream

/**
 * Real VPN implementation (Option A):
 * - Create TUN via Android VpnService
 * - Run sing-box as local SOCKS5 client -> your VLESS/WS/TLS server
 * - Run tun2socks (native AAR) to forward TUN traffic to the local SOCKS5
 *
 * Notes:
 * - To keep APK small, sing-box binary is downloaded on first connect.
 * - APK size is kept low by building --split-per-abi.
 */
class VpnTunnelService : VpnService() {

  companion object {
    private const val TAG = "GravilVPN"

    const val ACTION_START = "com.example.gravil.VPN_START"
    const val ACTION_STOP = "com.example.gravil.VPN_STOP"
    const val EXTRA_VLESS_URL = "vlessUrl"

    // Pin a known-good version for stability.
    private const val SINGBOX_VERSION = "1.13.11"
    private const val SINGBOX_TARBALL_URL =
      "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-android-arm64.tar.gz"

    private const val NOTIF_CHANNEL = "gravil_vpn"
    private const val NOTIF_ID = 9001

    private const val LOCAL_SOCKS = "127.0.0.1:10808"
  }

  private var tun: ParcelFileDescriptor? = null
  private var singboxProc: Process? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_START -> {
        val vlessUrl = intent.getStringExtra(EXTRA_VLESS_URL) ?: ""
        startTunnel(vlessUrl)
      }
      ACTION_STOP -> stopTunnel()
    }
    return Service.START_STICKY
  }

  private fun startTunnel(vlessUrl: String) {
    if (tun != null) return

    startForeground(NOTIF_ID, buildNotification("Connecting…"))

    try {
      val builder = Builder()
        .setSession("Gravil VPN")
        .addAddress("10.7.0.2", 32)
        .addRoute("0.0.0.0", 0)
        .addDnsServer("1.1.1.1")

      // Protect the local loopback sockets used by sing-box.
      // (Best-effort; some versions ignore protect for loopback.)

      tun = builder.establish() ?: throw IllegalStateException("Failed to establish TUN")

      // 1) Ensure sing-box binary exists
      val bin = ensureSingBoxBinary()

      // 2) Generate sing-box config that exposes a local SOCKS5 inbound
      val configFile = writeSingBoxConfig(vlessUrl)

      // 3) Start sing-box (SOCKS5 on 127.0.0.1:10808)
      startSingBox(bin, configFile)

      // 4) Start tun2socks engine to forward TUN -> SOCKS5
      startTun2Socks()

      updateNotification("Connected")
    } catch (t: Throwable) {
      Log.e(TAG, "VPN start failed", t)
      updateNotification("Failed")
      stopTunnel()
    }
  }

  private fun startTun2Socks() {
    val pfd = tun ?: throw IllegalStateException("TUN not established")

    // Feed tun fd to native engine via /proc/self/fd/<n>
    val tunPath = "/proc/self/fd/${pfd.fd}"

    val key = Key().apply {
      setLogLevel("error")
      setMTU(1500)
      setDevice(tunPath)
      setInterface("tun0")
      setProxy("socks5://$LOCAL_SOCKS")
      // no REST API
      setRestAPI("")
      // no fwmark by default
      setMark(0)
    }

    Engine.insert(key)
    Engine.start()
  }

  private fun stopTun2Socks() {
    try {
      Engine.stop()
    } catch (_: Throwable) {
    }
  }

  private fun startSingBox(bin: File, configFile: File) {
    stopSingBox()

    bin.setExecutable(true)

    // Run in foreground; use workDir = filesDir
    val pb = ProcessBuilder(
      bin.absolutePath,
      "run",
      "-c",
      configFile.absolutePath
    )
      .directory(filesDir)
      .redirectErrorStream(true)

    singboxProc = pb.start()

    // Consume output asynchronously to avoid blocking.
    Thread {
      try {
        singboxProc?.inputStream?.bufferedReader()?.forEachLine {
          // Keep logs quiet by default.
          if (it.contains("error", ignoreCase = true)) Log.w(TAG, "sing-box: $it")
        }
      } catch (_: Throwable) {
      }
    }.start()
  }

  private fun stopSingBox() {
    try {
      singboxProc?.destroy()
    } catch (_: Throwable) {
    }
    singboxProc = null
  }

  private fun stopTunnel() {
    stopTun2Socks()
    stopSingBox()

    try {
      tun?.close()
    } catch (_: Throwable) {
    }
    tun = null

    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf()
  }

  override fun onDestroy() {
    stopTunnel()
    super.onDestroy()
  }

  override fun onBind(intent: Intent): IBinder? = null

  // ---------------------------
  // Notification helpers
  // ---------------------------

  private fun buildNotification(text: String): Notification {
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val ch = NotificationChannel(NOTIF_CHANNEL, "Gravil VPN", NotificationManager.IMPORTANCE_LOW)
      nm.createNotificationChannel(ch)
    }

    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, NOTIF_CHANNEL)
    } else {
      @Suppress("DEPRECATION")
      Notification.Builder(this)
    }

    return builder
      .setContentTitle("Gravil VPN")
      .setContentText(text)
      .setSmallIcon(R.mipmap.ic_launcher)
      .build()
  }

  private fun updateNotification(text: String) {
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    nm.notify(NOTIF_ID, buildNotification(text))
  }

  // ---------------------------
  // sing-box setup
  // ---------------------------

  private fun ensureSingBoxBinary(): File {
    val dir = File(filesDir, "vpn_core").apply { mkdirs() }
    val bin = File(dir, "sing-box")

    if (bin.exists() && bin.length() > 1024 * 1024) return bin

    // Download tar.gz then extract the 'sing-box' file.
    val tmp = File(dir, "sing-box.tar.gz")
    downloadTo(SINGBOX_TARBALL_URL, tmp)

    extractTarGzSingleFile(tmp, "sing-box-${SINGBOX_VERSION}-android-arm64/sing-box", bin)
    bin.setExecutable(true)

    // cleanup
    tmp.delete()

    return bin
  }

  private fun writeSingBoxConfig(vlessUrl: String): File {
    val uri = Uri.parse(vlessUrl)

    val uuid = uri.userInfo?.substringBefore(":") ?: uri.userInfo ?: ""
    val server = uri.host ?: ""
    val port = if (uri.port > 0) uri.port else 443

    fun q(name: String): String? = uri.getQueryParameter(name)

    val sni = q("sni") ?: q("host") ?: uri.host
    val host = q("host") ?: sni
    val path = q("path") ?: "/"
    val allowInsecure = (q("allowInsecure") == "1" || q("allowInsecure") == "true")

    // sing-box JSON config
    val json = """
{
  \"log\": { \"level\": \"error\" },
  \"inbounds\": [
    {
      \"type\": \"socks\",
      \"tag\": \"socks-in\",
      \"listen\": \"127.0.0.1\",
      \"listen_port\": 10808
    }
  ],
  \"outbounds\": [
    {
      \"type\": \"vless\",
      \"tag\": \"proxy\",
      \"server\": \"$server\",
      \"server_port\": $port,
      \"uuid\": \"$uuid\",
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$sni\",
        \"insecure\": ${allowInsecure.toString()}
      },
      \"transport\": {
        \"type\": \"ws\",
        \"path\": \"$path\",
        \"headers\": {
          \"Host\": \"$host\"
        }
      }
    },
    { \"type\": \"direct\", \"tag\": \"direct\" },
    { \"type\": \"block\", \"tag\": \"block\" }
  ],
  \"route\": {
    \"auto_detect_interface\": true,
    \"final\": \"proxy\"
  }
}
""".trimIndent()

    val dir = File(filesDir, "vpn_core").apply { mkdirs() }
    val f = File(dir, "sing-box.json")
    f.writeText(json)
    return f
  }

  // ---------------------------
  // Networking + extraction
  // ---------------------------

  private fun downloadTo(url: String, out: File) {
    val conn = (URL(url).openConnection() as HttpURLConnection).apply {
      instanceFollowRedirects = true
      connectTimeout = 15000
      readTimeout = 30000
    }
    conn.inputStream.use { input ->
      FileOutputStream(out).use { fos ->
        input.copyTo(fos)
      }
    }
  }

  /**
   * Minimal tar.gz extractor for one file.
   */
  private fun extractTarGzSingleFile(tarGz: File, wantedPath: String, outFile: File) {
    GZIPInputStream(BufferedInputStream(tarGz.inputStream())).use { gz ->
      while (true) {
        val header = ByteArray(512)
        val read = gz.read(header)
        if (read < 0) break
        if (read != 512) throw IllegalStateException("Bad tar header")

        val name = header.copyOfRange(0, 100).toString(Charset.forName("UTF-8")).trimEnd('\u0000')
        if (name.isEmpty()) break

        val sizeOct = header.copyOfRange(124, 136).toString(Charset.forName("UTF-8")).trim().trimEnd('\u0000')
        val size = sizeOct.ifEmpty { "0" }.trim().toLong(8)

        val blocks = ((size + 511) / 512).toInt()

        if (name == wantedPath) {
          FileOutputStream(outFile).use { fos ->
            var remaining = size
            val buf = ByteArray(8192)
            while (remaining > 0) {
              val n = gz.read(buf, 0, minOf(buf.size.toLong(), remaining).toInt())
              if (n <= 0) throw IllegalStateException("Unexpected EOF")
              fos.write(buf, 0, n)
              remaining -= n
            }
          }

          // Skip padding to 512 boundary
          val padding = (512 - (size % 512)) % 512
          if (padding > 0) gz.skip(padding)

          // Done
          return
        } else {
          // Skip file body
          var toSkip = size
          val buf = ByteArray(8192)
          while (toSkip > 0) {
            val n = gz.read(buf, 0, minOf(buf.size.toLong(), toSkip).toInt())
            if (n <= 0) throw IllegalStateException("Unexpected EOF")
            toSkip -= n
          }
          val padding = (512 - (size % 512)) % 512
          if (padding > 0) gz.skip(padding)
        }
      }
    }

    throw IllegalStateException("File not found in tar: $wantedPath")
  }
}

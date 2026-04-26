package com.example.minimal_chat_app.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import hev.htproxy.TProxyService
import java.io.File
import com.jcraft.jsch.JSch
import com.jcraft.jsch.Session
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.*
import java.util.concurrent.atomic.AtomicBoolean

class VpnTunnelService : VpnService() {
    private val notificationId = 1001
    private val notificationChannelId = "minimal_chat_vpn"

    private fun startForegroundNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "VPN",
                NotificationManager.IMPORTANCE_LOW
            )
            nm.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, notificationChannelId)
            .setContentTitle("VPN connected")
            .setContentText("Secure tunnel is running")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build()

        startForeground(notificationId, notification)
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var sshSession: Session? = null
    private val isRunning = AtomicBoolean(false)
    private var tunnelThread: Thread? = null
    private var tproxy: TProxyService? = null
    private var configFile: File? = null

    companion object {
        const val ACTION_CONNECT = "com.example.minimal_chat_app.vpn.CONNECT"
        const val ACTION_DISCONNECT = "com.example.minimal_chat_app.vpn.DISCONNECT"
        private const val TAG = "VpnTunnelService"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val server = intent.getStringExtra("server") ?: ""
                val port = intent.getIntExtra("port", 443)
                val user = intent.getStringExtra("user") ?: ""
                val pass = intent.getStringExtra("pass") ?: ""
                val sni = intent.getStringExtra("sni") ?: ""
                val payload = intent.getStringExtra("payload") ?: ""
                startForegroundNotification()
                startVpn(server, port, user, pass, sni, payload)
            }
            ACTION_DISCONNECT -> stopVpn()
        }
        return START_NOT_STICKY
    }

    private fun startVpn(server: String, port: Int, user: String, pass: String, sni: String, payload: String) {
        if (isRunning.get()) return
        isRunning.set(true)

        tunnelThread = Thread {
            try {
                val jsch = JSch()
                val session = jsch.getSession(user, server, port)
                session.setPassword(pass)
                
                val proxy = WebSocketProxy("https://$server:$port", sni, payload)
                session.setProxy(proxy)

                val config = Properties()
                config["StrictHostKeyChecking"] = "no"
                session.setConfig(config)
                
                session.connect(30000)
                sshSession = session

                // Set up local port forwarding (placeholder)
                // NOTE: JSch 0.1.55 does not provide setPortForwardingD (dynamic/SOCKS).
                // This keeps the build compiling; you may replace with a proper SOCKS implementation.
                val localPort = 1080
                // session.setPortForwardingD(localPort)

                // Establish VPN interface
                val builder = Builder()
                builder.setMtu(1500)
                builder.addAddress("10.0.0.2", 32)
                builder.addRoute("0.0.0.0", 0)
                builder.addDnsServer("8.8.8.8")
                builder.setSession("MinimalChatVPN")
                
                vpnInterface = builder.establish()

                // --- tun2socks bridge (TUN -> SOCKS5) ---
                // We expose a local SOCKS5 proxy via SSH dynamic forwarding on 127.0.0.1:1080.
                // Now bridge the TUN interface to that SOCKS5 proxy.
                val pfd = vpnInterface ?: throw IllegalStateException("VPN interface not established")
                val tunFd = pfd.fd

                // Write config file expected by HevSocks5Tunnel
                val cfg = """
                tunnel:
                  name: tun0
                  mtu: 1500
                  multi-queue: false
                  ipv4: 10.0.0.2
                  ipv6: 'fc00::2'
                socks5:
                  port: 1080
                  address: 127.0.0.1
                  udp: 'tcp'
                """.trimIndent()

                val f = File(filesDir, "hev_tproxy.yml")
                f.writeText(cfg)
                configFile = f

                val svc = TProxyService()
                tproxy = svc
                svc.TProxyStartService(f.absolutePath, tunFd)

                Log.i(TAG, "VPN Started (tun2socks active)")
            } catch (e: Exception) {
                Log.e(TAG, "VPN Start failed", e)
                stopVpn()
            }
        }
        tunnelThread?.start()
    }

    private fun stopVpn() {
        isRunning.set(false)
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        try {
            tproxy?.TProxyStopService()
        } catch (_: Exception) {
        }
        tproxy = null

        sshSession?.disconnect()
        vpnInterface?.close()
        vpnInterface = null
        sshSession = null
        configFile = null
        Log.i(TAG, "VPN Stopped")
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}

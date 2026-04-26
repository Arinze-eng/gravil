package com.example.gravil

import android.app.Service
import android.content.Intent
import android.net.VpnService
import android.os.IBinder
import android.os.ParcelFileDescriptor

/**
 * Minimal VPNService scaffold.
 *
 * IMPORTANT:
 * - This establishes a TUN interface so Android shows a VPN connection.
 * - You must plug sing-box (or Xray) core here to actually tunnel traffic.
 *   Recommended: run sing-box-for-android core or embed sing-box as a native module.
 */
class VpnTunnelService : VpnService() {

  companion object {
    const val ACTION_START = "com.example.gravil.VPN_START"
    const val ACTION_STOP = "com.example.gravil.VPN_STOP"
    const val EXTRA_VLESS_URL = "vlessUrl"
  }

  private var tun: ParcelFileDescriptor? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_START -> {
        // vlessUrl provided for future sing-box config generation
        startTunnel()
      }
      ACTION_STOP -> stopTunnel()
    }
    return Service.START_STICKY
  }

  private fun startTunnel() {
    if (tun != null) return

    val builder = Builder()
      .setSession("Gravil VPN")
      .addAddress("10.7.0.2", 32)
      .addRoute("0.0.0.0", 0)
      .addDnsServer("1.1.1.1")

    tun = builder.establish()
  }

  private fun stopTunnel() {
    try {
      tun?.close()
    } catch (_: Throwable) {
    }
    tun = null
    stopSelf()
  }

  override fun onDestroy() {
    stopTunnel()
    super.onDestroy()
  }

  override fun onBind(intent: Intent): IBinder? = null
}

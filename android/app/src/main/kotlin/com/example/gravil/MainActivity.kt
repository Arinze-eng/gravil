package com.example.gravil

import io.flutter.embedding.android.FlutterActivity

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val channel = "gravil/vpn"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
      when (call.method) {
        "start" -> {
          val vlessUrl = call.argument<String>("vlessUrl") ?: ""
          val prepare = android.net.VpnService.prepare(this)
          if (prepare != null) {
            // User consent required
            startActivityForResult(prepare, 1001)
            result.error("VPN_PERMISSION", "VPN permission required", null)
            return@setMethodCallHandler
          }
          val i = Intent(this, VpnTunnelService::class.java).apply {
            action = VpnTunnelService.ACTION_START
            putExtra(VpnTunnelService.EXTRA_VLESS_URL, vlessUrl)
          }
          startService(i)
          result.success(null)
        }

        "stop" -> {
          val i = Intent(this, VpnTunnelService::class.java).apply { action = VpnTunnelService.ACTION_STOP }
          startService(i)
          result.success(null)
        }

        else -> result.notImplemented()
      }
    }
  }
}

package com.example.minimal_chat_app

import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.minimal_chat_app.vpn.VpnTunnelService

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.minimal_chat_app/vpn"
    private val VPN_REQUEST_CODE = 100

    private var pendingVpnData: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val args = call.arguments as Map<String, Any>
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        pendingVpnData = args
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        startVpnService(args)
                    }
                    result.success(true)
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE && resultCode == RESULT_OK) {
            pendingVpnData?.let { startVpnService(it) }
            pendingVpnData = null
        }
    }

    private fun startVpnService(args: Map<String, Any>) {
        val intent = Intent(this, VpnTunnelService::class.java).apply {
            action = VpnTunnelService.ACTION_CONNECT
            putExtra("server", args["server"] as String)
            putExtra("port", args["port"] as Int)
            putExtra("user", args["user"] as String)
            putExtra("pass", args["pass"] as String)
            putExtra("sni", args["sni"] as String)
            putExtra("payload", args["payload"] as String)
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun stopVpnService() {
        val intent = Intent(this, VpnTunnelService::class.java).apply {
            action = VpnTunnelService.ACTION_DISCONNECT
        }
        startService(intent)
    }
}

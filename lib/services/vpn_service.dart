import 'package:flutter/services.dart';

class VpnService {
  static const _channel = MethodChannel('com.example.minimal_chat_app/vpn');

  static Future<void> startVpn({
    required String server,
    required int port,
    required String username,
    required String password,
    required String sni,
    required String payload,
  }) async {
    try {
      await _channel.invokeMethod('startVpn', {
        'server': server,
        'port': port,
        'user': username,
        'pass': password,
        'sni': sni,
        'payload': payload,
      });
    } on PlatformException catch (e) {
      print("Failed to start VPN: '${e.message}'.");
    }
  }

  static Future<void> stopVpn() async {
    try {
      await _channel.invokeMethod('stopVpn');
    } on PlatformException catch (e) {
      print("Failed to stop VPN: '${e.message}'.");
    }
  }
}

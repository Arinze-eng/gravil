import 'package:flutter/services.dart';

class VpnService {
  static const _ch = MethodChannel('gravil/vpn');

  static Future<void> start({required String vlessUrl}) async {
    await _ch.invokeMethod('start', {'vlessUrl': vlessUrl});
  }

  static Future<void> stop() async {
    await _ch.invokeMethod('stop');
  }
}

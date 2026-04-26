import 'package:flutter/material.dart';
import 'vpn_service.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  bool _enabled = false;
  bool _loading = false;

  // Your provided VLESS URL (kept in code for now). You can move to remote config later.
  static const vlessUrl =
      'vless://a6f1755f-0140-4bea-8727-0db1bed7c4df@172.67.187.6:443?allowInsecure=1&encryption=none&host=juzi.qea.ccwu.cc&path=%2F&security=tls&sni=juzi.qea.ccwu.cc&type=ws#vless-SG';

  Future<void> _toggle(bool v) async {
    setState(() {
      _loading = true;
    });
    try {
      if (v) {
        await VpnService.start(vlessUrl: vlessUrl);
      } else {
        await VpnService.stop();
      }
      setState(() => _enabled = v);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('VPN error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy VPN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VPN Toggle', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('Uses Android VPNService + sing-box style config (VLESS over WS/TLS).'),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _enabled,
                      onChanged: _loading ? null : _toggle,
                      title: Text(_enabled ? 'Connected' : 'Disconnected'),
                      subtitle: const Text('Single toggle to connect to your server'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: The native VPN bridge is scaffolded in Android (Kotlin) via a platform channel.\n'
              'If you want iOS support later, we can add NEPacketTunnelProvider.',
            ),
          ],
        ),
      ),
    );
  }
}

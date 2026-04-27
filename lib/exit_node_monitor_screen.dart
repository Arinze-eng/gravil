import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExitNodeMonitorScreen extends ConsumerWidget {
  static String routeName = '/exit-monitor';

  const ExitNodeMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myInfoAsync = ref.watch(myPeerInfoProvider);
    final peersAsync = ref.watch(knownPeersProvider);

    return AppShell(
      selected: AppSection.exitMonitor,
      appBar: AppBar(title: const Text('Exit Node Monitor')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: myInfoAsync.when(
            data: (myInfo) {
              return peersAsync.when(
                data: (peers) {
                  final list = peers ?? <KnownPeer>[];
                  final myPeerID = myInfo.peerID;

                  final myUsingPeerID = myInfo.socks5.usingPeerID;
                  final myUsingPeerName = myInfo.socks5.usingPeerName;
                  final myExitPercent = myUsingPeerID.isEmpty ? 0.0 : 1.0;

                  final routingThroughMe = list.where((p) => p.reportedUsingPeerID == myPeerID).toList();

                  return ListView(
                    children: [
                      _sectionTitle(context, 'Your routing status'),
                      _statusCard(
                        context,
                        title: 'You are using',
                        subtitle: myUsingPeerID.isEmpty ? 'Direct Internet (no exit node)' : 'Exit node: $myUsingPeerName',
                        percent: myExitPercent,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle(context, 'Peers routing through you'),
                      if (routingThroughMe.isEmpty)
                        _hintCard(context, 'No peers are currently using you as an exit node.'),
                      for (final p in routingThroughMe)
                        _peerRowCard(
                          context,
                          peerName: p.displayName,
                          routeLabel: 'Using you as exit node',
                          percent: 1.0,
                        ),
                      const SizedBox(height: 16),

                      _sectionTitle(context, 'Routing map (who uses who)'),
                      if (list.isEmpty) _hintCard(context, 'No known peers yet.'),
                      for (final p in list)
                        _peerRowCard(
                          context,
                          peerName: p.displayName,
                          routeLabel: p.reportedUsingPeerID.isEmpty
                              ? 'Direct Internet'
                              : 'Exit node: ${p.reportedUsingPeerName.isEmpty ? p.reportedUsingPeerID : p.reportedUsingPeerName}',
                          percent: p.reportedUsingPeerID.isEmpty ? 0.0 : 1.0,
                          extra: _shareHints(p),
                        ),

                      const SizedBox(height: 16),
                      _hintCard(
                        context,
                        'Percentages are based on current exit-node selection: 0% = not using an exit node, 100% = routing via an exit node.\n'
                        'This is the most reliable indicator without deep per-flow OS traffic accounting.',
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _errorBox('Failed to load peers: $e'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBox('Failed to load device status: $e'),
          ),
        ),
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  static Widget _hintCard(BuildContext context, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  static Widget _statusCard(BuildContext context, {required String title, required String subtitle, required double percent}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            _percentBar(context, percent),
          ],
        ),
      ),
    );
  }

  static Widget _peerRowCard(
    BuildContext context, {
    required String peerName,
    required String routeLabel,
    required double percent,
    String? extra,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(peerName, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 6),
            Text(routeLabel, style: Theme.of(context).textTheme.bodyMedium),
            if (extra != null && extra.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(extra, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            _percentBar(context, percent),
          ],
        ),
      ),
    );
  }

  static Widget _percentBar(BuildContext context, double percent) {
    final pct = (percent * 100).round();
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: percent,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 48, child: Text('$pct%')),
      ],
    );
  }

  static Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  static String _shareHints(KnownPeer p) {
    final parts = <String>[];
    if (p.weAllowUsingAsExitNode) parts.add('You allow this peer to use you as exit node');
    if (p.allowedUsingAsExitNode) parts.add('This peer allows you to use it as exit node');
    return parts.join(' • ');
  }
}

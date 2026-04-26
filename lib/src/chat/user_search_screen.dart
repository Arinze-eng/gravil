import 'package:flutter/material.dart';
import '../utils/supabase_client.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _q = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = const [];

  Future<void> _search() async {
    final query = _q.text.trim();
    if (query.isEmpty) return;

    setState(() => _loading = true);
    try {
      final me = supabase.auth.currentUser;
      final res = await supabase
          .from('profiles')
          .select('id,name,public_id,last_seen')
          .neq('id', me?.id ?? '')
          .or('public_id.eq.$query,name.ilike.%$query%')
          .limit(50);

      setState(() => _results = (res as List).cast<Map<String, dynamic>>());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search users')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: const InputDecoration(
                      labelText: 'Search by 5-digit ID or name',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(onPressed: _loading ? null : _search, child: const Text('Search')),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        return Card(
                          child: ListTile(
                            title: Text('${p['name']}  (#${p['public_id']})'),
                            subtitle: Text('Last seen: ${p['last_seen'] ?? '-'}'),
                            trailing: const Icon(Icons.chat_bubble_outline),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ChatScreen(peerId: p['id'] as String, peerName: p['name'] as String, peerPublicId: p['public_id'] as String)),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

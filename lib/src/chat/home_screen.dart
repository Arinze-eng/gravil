import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/supabase_client.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gravil'),
        actions: [
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserSearchScreen())), icon: const Icon(Icons.search)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserSearchScreen()));
        },
        label: const Text('New chat'),
        icon: const Icon(Icons.chat_bubble_outline),
      ),
      body: user == null
          ? const _LoggedOutView()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chats',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _RecentChatsList(myId: user.id)),
                ],
              ),
            ),
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Please sign in.'));
  }
}

class _RecentChatsList extends StatelessWidget {
  final String myId;
  const _RecentChatsList({required this.myId});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('MMM d, HH:mm');

    final stream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final msgs = (snap.data ?? const []).cast<Map<String, dynamic>>();
        if (msgs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No chats yet. Tap “New chat” to find a user and start chatting.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        // Reduce to latest message per room.
        final latestByRoom = <String, Map<String, dynamic>>{};
        for (final m in msgs) {
          final room = m['room_id'] as String?;
          if (room == null) continue;
          latestByRoom.putIfAbsent(room, () => m);
        }
        final latest = latestByRoom.values.toList();

        return ListView.separated(
          itemCount: latest.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = latest[i];
            final sender = m['sender_id'] as String;
            final receiver = m['receiver_id'] as String;
            final peerId = sender == myId ? receiver : sender;
            final createdAt = DateTime.tryParse(m['created_at'] ?? '')?.toLocal();

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: supabase.from('profiles').select('id,name,public_id,last_seen').eq('id', peerId).limit(1),
              builder: (context, psnap) {
                final p = (psnap.data?.isNotEmpty ?? false) ? psnap.data!.first : null;
                final peerName = (p?['name'] ?? 'User') as String;
                final peerPublicId = (p?['public_id'] ?? '-----') as String;

                final type = m['type'] as String;
                final preview = switch (type) {
                  'text' => (m['content'] as String).toString(),
                  'image' => '📷 Photo',
                  'voice' => '🎤 Voice note',
                  'file' => '📎 File',
                  _ => 'Message',
                };

                return Card(
                  child: ListTile(
                    title: Text('$peerName  (#$peerPublicId)'),
                    subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(createdAt == null ? '' : timeFmt.format(createdAt), style: Theme.of(context).textTheme.bodySmall),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(peerId: peerId, peerName: peerName, peerPublicId: peerPublicId),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

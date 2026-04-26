import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/supabase_client.dart';
import 'user_search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gravil'),
        actions: [
          IconButton(onPressed: () => context.go('/vpn'), icon: const Icon(Icons.vpn_lock)),
          IconButton(onPressed: () => context.go('/settings'), icon: const Icon(Icons.settings)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserSearchScreen()));
        },
        label: const Text('New chat'),
        icon: const Icon(Icons.search),
      ),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : const Padding(
              padding: EdgeInsets.all(16),
              child: _ChatsListPlaceholder(),
            ),
    );
  }
}

class _ChatsListPlaceholder extends StatelessWidget {
  const _ChatsListPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chats',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Search a user by 5-digit ID or name to start chatting.\n\nRealtime chat + read receipts are implemented in the conversation screen.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/supabase_client.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                    Text('Account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('User ID: ${user?.id ?? '-'}'),
                    Text('Email: ${user?.email ?? '-'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                await supabase.auth.signOut();
                if (!context.mounted) return;
                context.go('/login');
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

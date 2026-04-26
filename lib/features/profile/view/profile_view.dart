import 'package:flutter/material.dart';
import 'package:minimal_chat_app/features/auth/service/auth_service.dart';
import 'package:minimal_chat_app/services/supabase_client.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? 'unknown@example.com';
    final uid = user?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const CircleAvatar(
                  minRadius: 50,
                  child: Icon(Icons.person_rounded, size: 70),
                ),
                const SizedBox(height: 12),
                Text(
                  email.split('@').first,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(email),
              ],
            ),
            Container(
              margin: const EdgeInsets.all(20),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(25)),
              child: QrImageView(
                gapless: true,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                data: uid,
                version: 2,
                padding: const EdgeInsets.all(25),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: StadiumBorder(),
                      content: Text('Signed out'),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

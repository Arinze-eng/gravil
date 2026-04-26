import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/id.dart';
import '../utils/supabase_client.dart';
import '../widgets/app_logo.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _signup() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final email = _email.text.trim();
      final password = _password.text;
      final name = _name.text.trim();

      final authResp = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      final user = authResp.user;
      if (user == null) throw Exception('No user returned from signUp');

      // Create profile record with 5-digit public ID.
      final seed = Random().nextInt(1 << 31) ^ user.id.hashCode;
      final publicId = generateFiveDigitId(seed);

      await supabase.from('profiles').upsert({
        'id': user.id,
        'name': name,
        'public_id': publicId,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(onPressed: () => context.go('/login'), icon: const Icon(Icons.arrow_back)),
                  const SizedBox(width: 8),
                  Text('Create account', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.center, child: AppLogo()),
              const SizedBox(height: 18),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loading ? null : _signup,
                child: Text(_loading ? 'Creating…' : 'Sign up'),
              ),
              const SizedBox(height: 10),
              Text(
                'Note: Email verification must be disabled in your Supabase Auth settings for password sign-up to work without confirmation.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

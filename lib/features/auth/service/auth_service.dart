import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_client.dart';

class AuthService {
  Future<void> _ensureProfile(User user) async {
    final email = user.email ?? 'unknown@example.com';
    final name = email.split('@').first;

    // If profile already exists, do a simple upsert update.
    // If it doesn't, we must create a unique 4-digit `code`.
    final existing = await supabase
        .from('profiles')
        .select('id,code')
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'name': name,
        'code': existing['code'],
      }, onConflict: 'id');
      return;
    }

    final rand = Random.secure();

    // Retry a few times in case `code` collides (UNIQUE + 4 digits).
    for (var i = 0; i < 10; i++) {
      final code = (rand.nextInt(10000)).toString().padLeft(4, '0');
      try {
        await supabase.from('profiles').insert({
          'id': user.id,
          'email': email,
          'name': name,
          'code': code,
        });
        return;
      } on PostgrestException catch (e) {
        // Unique collision on code/email: retry with a different code.
        final msg = (e.message).toLowerCase();
        if (msg.contains('duplicate') || msg.contains('unique')) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Failed to allocate unique profile code. Please retry.');
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final resp = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = resp.user;
    if (user != null) {
      await _ensureProfile(user);
    }
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final resp = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    // If email confirmation is ON, user may be null until confirmed.
    // We'll create the profile on first successful login after verification.
    final user = resp.user;
    if (user != null) {
      await _ensureProfile(user);
    }

    return resp;
  }

  Future<void> resendVerificationEmail(String email) async {
    await supabase.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<void> signOut() => supabase.auth.signOut();
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minimal_chat_app/features/auth/components/auth_text_field.dart';
import 'package:minimal_chat_app/features/auth/providers/authProviders.dart';
import 'package:minimal_chat_app/features/auth/service/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginView extends ConsumerWidget {
  LoginView({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> login() async {
      ref.read(showResendVerificationProvider.notifier).state = false;

      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      try {
        await AuthService().signInWithEmailPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        // Common Supabase message when email confirmation is enabled
        final msg = e.message.toLowerCase();
        if (msg.contains('email') && msg.contains('confirm')) {
          ref.read(lastAuthEmailProvider.notifier).state = email;
          ref.read(showResendVerificationProvider.notifier).state = true;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }

    final showResend = ref.watch(showResendVerificationProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                size: 100,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 25),
              const Text(
                "Welcome back!",
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              AuthTextField(
                hintText: "Email",
                textController: emailController,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                hintText: "Password",
                obscureText: ref.watch(obscureTextProvider),
                textController: passwordController,
                toggleObscureText: () {
                  ref
                      .watch(obscureTextProvider.notifier)
                      .update((state) => !state);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: login,
                      child: const Text("Login"),
                    ),
                  ),
                ],
              ),
              if (showResend) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final email = ref.read(lastAuthEmailProvider);
                          try {
                            await AuthService().resendVerificationEmail(email);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Verification email resent. Please check your inbox.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                        child: const Text('Resend verification email'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Not a user?"),
                  TextButton(
                    onPressed: () {
                      ref
                          .watch(registerOrLoginProvider.notifier)
                          .update((state) => !state);
                    },
                    child: const Text("Register"),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

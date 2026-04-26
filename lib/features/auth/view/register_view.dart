import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minimal_chat_app/features/auth/components/auth_text_field.dart';
import 'package:minimal_chat_app/features/auth/providers/authProviders.dart';
import 'package:minimal_chat_app/features/auth/service/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterView extends ConsumerWidget {
  RegisterView({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> register() async {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (passwordConfirmController.text != passwordController.text) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => const AlertDialog(
              alignment: Alignment.center,
              title: Text("Password doesn't match"),
            ),
          );
        }
        return;
      }

      try {
        await AuthService().signUpWithEmailPassword(
          email: email,
          password: password,
        );

        // Always treat sign-up as "verify email" flow.
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Verify your email'),
              content: Text(
                'A verification email was sent to $email. '
                'After verifying, come back and sign in.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await AuthService().resendVerificationEmail(email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Verification email resent. Check inbox.'),
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
                  child: const Text('Resend email'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(registerOrLoginProvider.notifier).state = true;
                  },
                  child: const Text('Go to login'),
                ),
              ],
            ),
          );
        }
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();

        // "Users that sign up never sign up again but sign in"
        if (msg.contains('already') && msg.contains('registered')) {
          ref.read(registerOrLoginProvider.notifier).state = true;
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
                "Let's Start chatting!",
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              AuthTextField(
                hintText: "Email",
                textController: emailController,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                toggleObscureText: () {
                  ref
                      .watch(obscureTextProvider.notifier)
                      .update((state) => !state);
                },
                hintText: "Password",
                textController: passwordController,
                obscureText: ref.watch(obscureTextProvider),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                toggleObscureText: () {
                  ref
                      .watch(obscureTextProvider.notifier)
                      .update((state) => !state);
                },
                hintText: "Confirm Password",
                textController: passwordConfirmController,
                obscureText: ref.watch(obscureTextProvider),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: register,
                      child: const Text("Register"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already a user?"),
                  TextButton(
                    onPressed: () {
                      ref
                          .watch(registerOrLoginProvider.notifier)
                          .update((state) => !state);
                    },
                    child: const Text("Login"),
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

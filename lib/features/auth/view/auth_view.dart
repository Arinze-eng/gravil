import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minimal_chat_app/features/auth/view/login_or_register.dart';
import 'package:minimal_chat_app/features/chatlist/view/chatlist_view.dart';
import 'package:minimal_chat_app/services/supabase_client.dart';

class AuthView extends ConsumerWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: StreamBuilder(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = supabase.auth.currentSession;
          if (session != null) {
            return const ChatListView();
          }
          return const LoginOrRegister();
        },
      ),
    );
  }
}

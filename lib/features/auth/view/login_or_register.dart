import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minimal_chat_app/features/auth/providers/authProviders.dart';
import 'package:minimal_chat_app/features/auth/view/login_view.dart';
import 'package:minimal_chat_app/features/auth/view/register_view.dart';

class LoginOrRegister extends ConsumerWidget {
  const LoginOrRegister({super.key});

  @override
  Widget build(BuildContext context, ref) {
    if (ref.watch(registerOrLoginProvider)) {
      return LoginView();
    } else {
      return RegisterView();
    }
  }
}

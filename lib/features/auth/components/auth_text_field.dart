import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final String hintText;
  final bool obscureText;
  final TextEditingController textController;
  final Function()? toggleObscureText;
  const AuthTextField(
      {super.key,
      required this.hintText,
      this.obscureText = false,
      required this.textController,
      this.toggleObscureText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onTapOutside: (event) {
        FocusScope.of(context).unfocus();
      },
      obscureText: obscureText,
      controller: textController,
      keyboardType: hintText.contains("Password")
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      decoration: InputDecoration(
        suffixIcon: hintText.contains("Password")
            ? IconButton(
                icon: Icon(
                    obscureText ? Icons.lock_rounded : Icons.lock_open_rounded),
                onPressed: toggleObscureText)
            : const SizedBox(),
        hintText: hintText,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(12),
          ),
        ),
      ),
    );
  }
}

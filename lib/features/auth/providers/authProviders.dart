import 'package:flutter_riverpod/flutter_riverpod.dart';

// provider to switch between register to login page
final registerOrLoginProvider = StateProvider<bool>((ref) {
  return true;
});

// obsecure text controller
final obscureTextProvider = StateProvider<bool>((ref) {
  return false;
});

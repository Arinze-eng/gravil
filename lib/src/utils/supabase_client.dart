import 'package:supabase_flutter/supabase_flutter.dart';

/// Provide these at build time:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Fallbacks are provided so the app can open and work out-of-the-box.
const _supabaseUrlEnv = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKeyEnv = String.fromEnvironment('SUPABASE_ANON_KEY');

// Fallbacks (public anon key is safe to ship)
const _supabaseUrlFallback = 'https://ljnparociyyggmxdewwv.supabase.co';
const _supabaseAnonKeyFallback =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxqbnBhcm9jaXl5Z2dteGRld3d2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5Njk3MzYsImV4cCI6MjA5MjU0NTczNn0.Lr4UR7llvzC9QxQIwOGdRxn4-2hyRgqYXAnfDRC1-C8';

String get supabaseUrl => _supabaseUrlEnv.isNotEmpty ? _supabaseUrlEnv : _supabaseUrlFallback;
String get supabaseAnonKey =>
    _supabaseAnonKeyEnv.isNotEmpty ? _supabaseAnonKeyEnv : _supabaseAnonKeyFallback;

SupabaseClient get supabase => Supabase.instance.client;

Future<void> initSupabase() async {
  // Safe to call multiple times.
  if (Supabase.instance.client.auth.currentSession != null || Supabase.instance.client.options.headers.isNotEmpty) {
    // already initialized in this runtime
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 20),
  );
}

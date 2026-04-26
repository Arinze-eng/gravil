import 'package:supabase_flutter/supabase_flutter.dart';

const _urlEnv = String.fromEnvironment('SUPABASE_URL');
const _anonEnv = String.fromEnvironment('SUPABASE_ANON_KEY');

// Fallbacks for local dev. Prefer --dart-define / CI secrets.
const _urlFallback = 'https://ljnparociyyggmxdewwv.supabase.co';
const _anonFallback =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxqbnBhcm9jaXl5Z2dteGRld3d2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5Njk3MzYsImV4cCI6MjA5MjU0NTczNn0.Lr4UR7llvzC9QxQIwOGdRxn4-2hyRgqYXAnfDRC1-C8';

String get supabaseUrl => _urlEnv.isNotEmpty ? _urlEnv : _urlFallback;
String get supabaseAnonKey => _anonEnv.isNotEmpty ? _anonEnv : _anonFallback;

SupabaseClient get supabase => Supabase.instance.client;

bool _inited = false;
Future<void> initSupabase() async {
  if (_inited) return;
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  _inited = true;
}

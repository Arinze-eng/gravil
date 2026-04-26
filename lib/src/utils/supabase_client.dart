import 'package:supabase_flutter/supabase_flutter.dart';

/// Provide these at build time:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

late final SupabaseClient supabase;

Future<void> initSupabase() async {
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    // App can still open UI, but auth/db will fail until configured.
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 20),
  );

  supabase = Supabase.instance.client;
}

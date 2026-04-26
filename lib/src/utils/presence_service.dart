import 'dart:async';

import 'supabase_client.dart';

class PresenceService {
  static StreamSubscription? _sub;
  static Timer? _timer;

  static void start() {
    _sub?.cancel();
    _timer?.cancel();

    _sub = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) {
        _timer?.cancel();
        return;
      }
      _touch();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _touch());
    });
  }

  static Future<void> _touch() async {
    final me = supabase.auth.currentUser;
    if (me == null) return;
    try {
      await supabase.from('profiles').update({'last_seen': DateTime.now().toUtc().toIso8601String()}).eq('id', me.id);
    } catch (_) {
      // ignore
    }
  }

  static void stop() {
    _sub?.cancel();
    _timer?.cancel();
  }
}

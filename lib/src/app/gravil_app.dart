import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import '../chat/home_screen.dart';
import '../profile/settings_screen.dart';
import '../vpn/vpn_screen.dart';
import 'theme.dart';
import '../utils/supabase_client.dart';
import '../utils/presence_service.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final loggedIn = session != null;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/vpn', builder: (c, s) => const VpnScreen()),
    ],
  );
});

class GravilApp extends ConsumerStatefulWidget {
  const GravilApp({super.key});

  @override
  ConsumerState<GravilApp> createState() => _GravilAppState();
}

class _GravilAppState extends ConsumerState<GravilApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initSupabase().then((_) {
      // Best-effort background last_seen updates
      try { PresenceService.start(); } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Best-effort last_seen updates handled in profile repository.
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Gravil',
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}

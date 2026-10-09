import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/router/routes.dart';
import 'package:nexus_mobile/core/router/transitions.dart';
import 'package:nexus_mobile/features/auth/login_screen.dart';
import 'package:nexus_mobile/features/auth/splash_screen.dart';
import 'package:nexus_mobile/shell/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

/// Paths are identical to nexus-web so pushes, widgets and shared links
/// deep-link with no translation table.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth is AuthUnknown) {
        return loc == '/splash' ? null : '/splash?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      final signedIn = auth is SignedIn;
      if (!signedIn) {
        if (loc == '/login') return null;
        final from = loc == '/splash' ? state.uri.queryParameters['from'] : state.uri.toString();
        return from == null || from == '/home' || from.startsWith('/login')
            ? '/login'
            : '/login?from=${Uri.encodeComponent(from)}';
      }
      if (loc == '/login' || loc == '/splash') {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') && !from.startsWith('//') ? from : '/home';
      }
      if (loc == '/') return '/home';
      return null;
    },
    routes: [
      fadeRoute('/splash', (_) => const SplashScreen()),
      fadeRoute('/login', (_) => const LoginScreen()),
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        pageBuilder: (context, state, child) =>
            fadeThroughPage(state, AppShell(location: state.uri.path, child: child)),
        routes: appRoutes,
      ),
      ...rootRoutes,
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

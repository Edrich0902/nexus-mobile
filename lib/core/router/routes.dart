import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/features/home/home_screen.dart';
import 'package:nexus_mobile/features/profile/profile_screen.dart';
import 'package:nexus_mobile/features/profile/sessions_screen.dart';

/// Routes rendered inside the shell (top bar + phone bar).
final appRoutes = <RouteBase>[
  GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
  GoRoute(
    path: '/profile',
    builder: (_, _) => const ProfileScreen(),
    routes: [GoRoute(path: 'sessions', builder: (_, _) => const SessionsScreen())],
  ),
];

/// Full-screen routes above the shell (camera, scanner, replay).
final rootRoutes = <RouteBase>[];

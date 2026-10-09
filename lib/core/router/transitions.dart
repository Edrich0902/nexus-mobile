import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// Tab roots and sign-in fade through: the old page dips out while the new
/// one settles in from a hair smaller. Detail routes keep the platform push
/// (and iOS swipe-back) from the theme.
CustomTransitionPage<void> fadeThroughPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: NxTiming.page,
  reverseTransitionDuration: NxTiming.base,
  transitionsBuilder: (context, animation, _, child) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: const Interval(.15, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(.3, 1, curve: Curves.easeInCubic),
    );
    if (reduceMotion(context)) return FadeTransition(opacity: enter, child: child);
    return FadeTransition(
      opacity: enter,
      child: ScaleTransition(scale: Tween<double>(begin: .965, end: 1).animate(enter), child: child),
    );
  },
);

/// A root route that fades through.
GoRoute fadeRoute(String path, Widget Function(GoRouterState state) build, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, pageBuilder: (_, s) => fadeThroughPage(s, build(s)), routes: routes);

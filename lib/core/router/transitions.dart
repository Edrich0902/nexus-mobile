import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

@visibleForTesting
const fadeThroughBackdropKey = ValueKey('fade-through-backdrop');

/// Tab roots and sign-in fade through. Swapping a root leaves the old page
/// fully drawn underneath until the new one lands, so the new page first
/// raises an opaque backdrop over it, then brings its own content in: the two
/// are never on screen together. Detail routes keep the platform push (and
/// iOS swipe-back) from the theme.
CustomTransitionPage<void> fadeThroughPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: NxTiming.page,
  reverseTransitionDuration: NxTiming.page,
  transitionsBuilder: (context, animation, _, child) => _FadeThrough(animation: animation, child: child),
);

/// A root route that fades through.
GoRoute fadeRoute(String path, Widget Function(GoRouterState state) build, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, pageBuilder: (_, s) => fadeThroughPage(s, build(s)), routes: routes);

class _FadeThrough extends StatelessWidget {
  const new({required this.animation, required this.child});

  /// The old content is gone by here; the new content starts after it.
  static const _handover = .35;

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cover = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, _handover, curve: Curves.easeOut),
    );
    final reveal = CurvedAnimation(
      parent: animation,
      curve: const Interval(_handover, 1, curve: NxTiming.settle),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          key: fadeThroughBackdropKey,
          opacity: cover,
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        FadeTransition(
          opacity: reveal,
          child: reduceMotion(context)
              ? child
              : ScaleTransition(scale: Tween<double>(begin: .985, end: 1).animate(reveal), child: child),
        ),
      ],
    );
  }
}

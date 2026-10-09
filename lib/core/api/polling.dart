import 'dart:async';

import 'package:flutter/widgets.dart';

/// Whether the app is on screen (web `document.visibilityState === 'visible'`).
bool get appInForeground {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// A periodic poll that skips its ticks while the app is backgrounded, so
/// screens never hit the API when nobody can see the result.
Timer foregroundPoll(Duration every, FutureOr<void> Function() tick) => Timer.periodic(every, (_) {
  if (appInForeground) unawaited(Future.sync(tick));
});

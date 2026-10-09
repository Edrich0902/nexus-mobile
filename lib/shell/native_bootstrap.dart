import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/native/deep_links.dart';
import 'package:nexus_mobile/core/native/notifications.dart';
import 'package:nexus_mobile/core/native/push.dart';
import 'package:nexus_mobile/core/native/shortcuts.dart';
import 'package:nexus_mobile/features/f1/f1_live_activity.dart';
import 'package:nexus_mobile/features/home/home_widgets.dart';

/// Starts the native integrations once: links, shortcuts and notification
/// taps always; push, widgets and the F1 Live Activity only while signed in.
final nativeBootstrapProvider = Provider<void>((ref) {
  if (!isMobilePlatform) return;
  ref.read(deepLinksProvider).start();
  unawaited(ref.read(shortcutsProvider).start());
  unawaited(ref.read(notificationsProvider).ready());

  ref.listen(authProvider, (previous, next) {
    switch (next) {
      case SignedIn():
        unawaited(ref.read(pushProvider).start());
        ref.read(homeWidgetSyncProvider).start();
        ref.read(f1LiveActivityProvider).start();
      case SignedOut():
        unawaited(ref.read(homeWidgetSyncProvider).clear());
        unawaited(ref.read(f1LiveActivityProvider).stop());
      case AuthUnknown():
        break;
    }
  }, fireImmediately: true);
});

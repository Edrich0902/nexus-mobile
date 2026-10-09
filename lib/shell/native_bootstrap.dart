import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/meta/app_meta.dart';
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
        ref.read(homeWidgetSyncProvider).start();
        unawaited(_startFlagged(ref));
      case SignedOut():
        unawaited(ref.read(homeWidgetSyncProvider).clear());
        unawaited(ref.read(f1LiveActivityProvider).stop());
      case AuthUnknown():
        break;
    }
  }, fireImmediately: true);
});

/// Push and Live Activities can be switched off server-side via `/v1/meta`.
Future<void> _startFlagged(Ref ref) async {
  AppMeta? meta;
  try {
    meta = await ref.read(appMetaProvider.future);
  } on Object {
    meta = null; // offline: default to on
  }
  if (meta?.feature('push') ?? true) unawaited(ref.read(pushProvider).start());
  if (meta?.feature('live_activities') ?? true) ref.read(f1LiveActivityProvider).start();
}

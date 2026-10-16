import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/features/home/activity.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/home/hub_api.dart';

/// Fingerprint of the newest stream row — used to stop polling once a sync
/// has written activity.
String? activityHeadFingerprint(ActivityState? state) {
  final first = state?.items.firstOrNull;
  if (first == null) return null;
  return '${first['id']}|${first['occurred_at']}';
}

/// Drop cached home stage, module pulses and stream so the next read hits the API.
void invalidateHomeSurfaces(WidgetRef ref) {
  refreshHomeModules(ref);
  ref
    ..invalidate(activityProvider)
    ..invalidate(nowProvider);
}

/// After a sync is queued, keep refetching home / More / stream until [isFresh]
/// (or we give up). Call via [unawaited] from sync handlers so the UI stays responsive.
Future<void> pollHomeSurfacesAfterSync(WidgetRef ref, {bool Function()? isFresh, int attempts = 16}) async {
  for (var i = 0; i < attempts; i++) {
    invalidateHomeSurfaces(ref);
    try {
      await Future.wait<void>([
        ref.read(activityProvider.future).then<void>((_) {}),
        ref.read(nowProvider.future).then<void>((_) {}),
        ref.read(sportsHomeProvider.future).then<void>((_) {}),
        ref.read(f1HomeProvider.future).then<void>((_) {}),
      ]);
    } on Object {
      // Soft / auth edges — keep trying.
    }
    if (isFresh?.call() ?? false) return;
    await Future<void>.delayed(Duration(milliseconds: 500 + (i * 250)));
  }
}

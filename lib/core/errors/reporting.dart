import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash + error reporting. A no-op when no SENTRY_DSN is configured.
abstract final class Reporting {
  static bool get enabled => AppConfig.sentryDsn.isNotEmpty;

  static Future<void> run(FutureOr<void> Function() app) async {
    if (!enabled) {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };
      await app();
      return;
    }
    await SentryFlutter.init((o) {
      o
        ..dsn = AppConfig.sentryDsn
        ..environment = AppConfig.env
        ..tracesSampleRate = AppConfig.isProd ? .2 : 1
        ..sendDefaultPii = false
        ..beforeSend = _scrub;
    }, appRunner: app);
  }

  /// Never ship bearer tokens or passwords in breadcrumbs / request data.
  static SentryEvent? _scrub(SentryEvent event, Hint hint) {
    final req = event.request;
    if (req == null) return event;
    req.headers = Map<String, String>.from(req.headers)..removeWhere((k, _) => k.toLowerCase() == 'authorization');
    return event;
  }

  static void capture(Object error, [StackTrace? stack]) {
    if (error is DioException && error.response != null && (error.response!.statusCode ?? 0) < 500) return;
    if (enabled) {
      unawaited(Sentry.captureException(error, stackTrace: stack));
    } else if (kDebugMode) {
      debugPrint('Nexus error: $error');
    }
  }
}

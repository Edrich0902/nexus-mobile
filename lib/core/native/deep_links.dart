import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:nexus_mobile/core/router/app_router.dart';

/// An in-app path from an untrusted source (push payload, widget, link).
/// Only same-app absolute paths pass; anything else returns null.
String? safeAppPath(String? raw) {
  final path = raw?.trim() ?? '';
  if (path.isEmpty || path.length > 512) return null;
  if (!path.startsWith('/') || path.startsWith('//')) return null;
  if (path.contains('..') || path.contains(r'\')) return null;
  return path;
}

/// `nexus://open/cellar/wines/3` and `https://<web host>/cellar/wines/3`
/// both resolve to `/cellar/wines/3`. Paths match nexus-web one-to-one.
String? appPathFromUri(Uri uri, {String webHost = AppConfig.webHost}) {
  switch (uri.scheme.toLowerCase()) {
    case AppConfig.urlScheme when uri.host == 'open':
      break;
    case 'https' when webHost.isNotEmpty && uri.host.toLowerCase() == webHost.toLowerCase():
      break;
    default:
      return null;
  }
  final path = uri.path.isEmpty || uri.path == '/' ? '/home' : uri.path;
  return safeAppPath(uri.hasQuery ? '$path?${uri.query}' : path);
}

final deepLinksProvider = Provider<DeepLinks>((ref) {
  final links = DeepLinks(ref);
  ref.onDispose(links.dispose);
  return links;
});

/// Routes incoming links (cold start and while running) through go_router.
/// The router's auth redirect keeps the target across sign-in.
class DeepLinks {
  DeepLinks(this._ref);

  final Ref _ref;
  StreamSubscription<Uri>? _sub;

  void start() {
    if (_sub != null) return;
    try {
      _sub = AppLinks().uriLinkStream.listen((uri) {
        if (appPathFromUri(uri) case final path?) open(path);
      }, onError: (_) {});
    } on Object {
      // No platform channel (tests / unsupported platform).
    }
  }

  void open(String? path) => _ref.read(routerProvider).go(safeAppPath(path) ?? '/home');

  void dispose() => unawaited(_sub?.cancel());
}

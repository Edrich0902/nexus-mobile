import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/auth/session.dart';
import 'package:nexus_mobile/core/native/push.dart';
import 'package:nexus_mobile/design/theme.dart';
import 'package:nexus_mobile/design/tokens.g.dart';

typedef Handler = Object? Function(Map<String, dynamic>? query, Object? data);

/// In-memory Keychain stand-in.
class MemorySessionStore extends SessionStore {
  AuthSession? stored;

  @override
  AuthSession? get current => stored;

  @override
  Future<AuthSession?> read() async => stored;

  @override
  Future<void> write(AuthSession? session) async => stored = session;
}

/// Routes `METHOD /path` to canned handlers and records every call.
class FakeApi extends ApiClient {
  FakeApi(this.routes) : super(MemorySessionStore());

  final Map<String, Handler> routes;
  final calls = <String>[];

  Object? _handle(String key, Map<String, dynamic>? query, Object? data) {
    calls.add(key);
    final handler = routes[key];
    if (handler == null) throw StateError('No fake for $key');
    return handler(query, data);
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query, CancelToken? cancel}) async =>
      _handle('GET $path', query, null);

  @override
  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? query}) async =>
      _handle('POST $path', query, data);

  @override
  Future<dynamic> delete(String path, {Object? data, Map<String, dynamic>? query}) async =>
      _handle('DELETE $path', query, data);
}

class FakePush extends PushNotifications {
  FakePush(super._ref);

  int unregistered = 0;

  @override
  Future<void> start() async {}

  @override
  Future<void> unregister() async => unregistered++;
}

/// Auth already resolved to a signed-in user.
class SignedInAuth extends AuthController {
  @override
  AuthState build() => const SignedIn(User(id: 1, name: 'Edrich Test', email: 'e@example.com'));
}

/// Wraps [child] in the Nexus theme + a provider scope.
Widget nexusTestApp(Widget child, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildNexusTheme(SectionKey.home.ambient),
    home: Scaffold(body: child),
  ),
);

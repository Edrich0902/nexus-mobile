import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/session.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/core/native/push.dart';

@immutable
class User {
  const User({required this.id, required this.name, required this.email, this.media, this.createdAt});

  factory User.fromJson(Json j) => User(
    id: j.integer('id') ?? 0,
    name: j.text('name'),
    email: j.text('email'),
    media: MediaImage.fromJson(j.obj('media')),
    createdAt: j.date('created_at'),
  );

  final int id;
  final String name;
  final String email;
  final MediaImage? media;
  final DateTime? createdAt;

  User copyWith({String? name, MediaImage? media}) =>
      User(id: id, name: name ?? this.name, email: email, media: media ?? this.media, createdAt: createdAt);

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut({this.expired = false});
  final bool expired;
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final User user;
}

String deviceName() {
  final os = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    _ => 'mobile',
  };
  return 'nexus-mobile · $os';
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Current user or null — convenient for widgets that only render when signed in.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authProvider);
  return state is SignedIn ? state.user : null;
});

class AuthController extends Notifier<AuthState> {
  ApiClient get _api => ref.read(apiClientProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  AuthState build() {
    final api = ref.watch(apiClientProvider)
      ..onUnauthorized = () {
        if (state is SignedIn) state = const SignedOut(expired: true);
      }
      ..onRefresh = refresh;
    ref.onDispose(() {
      api
        ..onUnauthorized = null
        ..onRefresh = null;
    });
    unawaited(_restore());
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    final session = await _store.read();
    if (session == null || session.isExpired) {
      await _store.write(null);
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(User.fromJson(asJson(await _api.get('/auth/me'))));
    } on Object catch (e) {
      final err = ApiError.from(e);
      // Offline at launch: keep the session and let screens show offline states.
      if (err.isOffline) {
        state = const SignedIn(User(id: 0, name: '', email: ''));
        unawaited(_retryMe());
      } else {
        state = const SignedOut();
      }
    }
  }

  Future<void> _retryMe() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    try {
      state = SignedIn(User.fromJson(asJson(await _api.get('/auth/me'))));
    } on Object {
      // stay optimistic; the next request will surface the problem
    }
  }

  Future<void> login({required String email, required String password, bool remember = true}) async {
    final json = asJson(
      await _api.post(
        '/auth/login',
        data: {'email': email, 'password': password, 'remember': remember, 'device_name': deviceName()},
      ),
    );
    await _store.write(AuthSession.fromJson(json));
    state = SignedIn(User.fromJson(json.obj('user') ?? {}));
  }

  Future<bool> refresh() async {
    try {
      final json = asJson(await _api.post('/auth/refresh'));
      await _store.write(AuthSession.fromJson(json));
      final user = json.obj('user');
      if (user != null) state = SignedIn(User.fromJson(user));
      return true;
    } on Object {
      return false;
    }
  }

  void updateUser(User user) => state = SignedIn(user);

  Future<void> reloadUser() async {
    state = SignedIn(User.fromJson(asJson(await _api.get('/auth/me'))));
  }

  Future<void> logout({bool everywhere = false}) async {
    await ref.read(pushProvider).unregister();
    try {
      await _api.post(everywhere ? '/auth/logout-all' : '/auth/logout');
    } on Object {
      // Local sign-out still happens; the token expires server-side.
    }
    await _store.write(null);
    state = const SignedOut();
  }
}

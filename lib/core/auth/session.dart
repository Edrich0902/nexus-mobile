import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sanctum bearer token + expiry. Stored only in the Keychain / Keystore.
class AuthSession {
  const AuthSession({required this.token, required this.expiresAt});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc(),
  );

  final String token;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!);

  /// Refresh when fewer than 10 minutes remain (same window as web).
  bool get shouldRefresh {
    if (expiresAt == null) return false;
    final left = expiresAt!.difference(DateTime.now().toUtc());
    return left > Duration.zero && left <= const Duration(minutes: 10);
  }

  Map<String, dynamic> toJson() => {'token': token, 'expires_at': expiresAt?.toIso8601String()};
}

class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  static const _key = 'nexus.session';
  final FlutterSecureStorage _storage;
  AuthSession? _cached;
  bool _loaded = false;

  AuthSession? get current => _cached;

  Future<AuthSession?> read() async {
    if (_loaded) return _cached;
    try {
      final raw = await _storage.read(key: _key);
      _cached = raw == null ? null : AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> write(AuthSession? session) async {
    _cached = session;
    _loaded = true;
    if (session == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    }
  }
}

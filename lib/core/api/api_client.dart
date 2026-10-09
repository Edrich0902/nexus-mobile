import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/auth/session.dart';
import 'package:nexus_mobile/core/config/app_config.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(sessionStoreProvider));
  ref.onDispose(client.close);
  return client;
});

/// Thin wrapper over Dio with the same behaviour as web `lib/http.ts`:
/// bearer auth, proactive token refresh, global 401 sign-out (except
/// integration endpoints) and a shared 429 cooldown with retry.
class ApiClient {
  ApiClient(this._sessions, {Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiRoot,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Accept': 'application/json'},
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final Dio dio;
  final SessionStore _sessions;

  /// Set by the auth controller; called when the Nexus session is rejected.
  VoidCallback? onUnauthorized;

  /// Set by the auth controller; performs `POST /auth/refresh`.
  Future<bool> Function()? onRefresh;

  Future<bool>? _refreshing;
  DateTime _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);

  Duration get rateLimitRemaining {
    final left = _cooldownUntil.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  static bool _isAuthBootstrap(String path) => path.contains('/auth/login') || path.contains('/auth/refresh');

  static bool _isIntegration(String path) => path.startsWith('/spotify') || path.startsWith('/github');

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final wait = rateLimitRemaining;
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait > const Duration(seconds: 15) ? const Duration(seconds: 15) : wait);
    }

    var session = await _sessions.read();
    if (!_isAuthBootstrap(options.path) && (session?.shouldRefresh ?? false) && onRefresh != null) {
      _refreshing ??= onRefresh!().whenComplete(() => _refreshing = null);
      await _refreshing;
      session = _sessions.current;
    }

    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.token}';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final status = error.response?.statusCode;
    final path = error.requestOptions.path;

    if (status == 401 && !path.contains('/auth/login') && !_isIntegration(path)) {
      await _sessions.write(null);
      onUnauthorized?.call();
      return handler.next(error);
    }

    if (status == 429) {
      final retries = (error.requestOptions.extra['retries'] as int?) ?? 0;
      final header = int.tryParse(error.response?.headers.value('retry-after') ?? '');
      final waitMs = header != null && header > 0 ? header * 1000 : 8000;
      final until = DateTime.now().add(Duration(milliseconds: waitMs));
      if (until.isAfter(_cooldownUntil)) _cooldownUntil = until;

      if (retries < 2 && error.requestOptions.data is! FormData) {
        final delay = math.min(
          rateLimitRemaining.inMilliseconds > 0 ? rateLimitRemaining.inMilliseconds : 2000 * (retries + 1),
          15000,
        );
        await Future<void>.delayed(Duration(milliseconds: delay));
        final opts = error.requestOptions..extra['retries'] = retries + 1;
        try {
          return handler.resolve(await dio.fetch<dynamic>(opts));
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
    }
    handler.next(error);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, CancelToken? cancel}) async =>
      (await dio.get<dynamic>(path, queryParameters: _clean(query), cancelToken: cancel)).data;

  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? query}) async =>
      (await dio.post<dynamic>(path, data: data, queryParameters: _clean(query))).data;

  Future<dynamic> put(String path, {Object? data}) async => (await dio.put<dynamic>(path, data: data)).data;

  Future<dynamic> patch(String path, {Object? data}) async => (await dio.patch<dynamic>(path, data: data)).data;

  Future<dynamic> delete(String path, {Object? data, Map<String, dynamic>? query}) async =>
      (await dio.delete<dynamic>(path, data: data, queryParameters: _clean(query))).data;

  Future<dynamic> upload(
    String path,
    FormData form, {
    void Function(double progress)? onProgress,
    CancelToken? cancel,
  }) async => (await dio.post<dynamic>(
    path,
    data: form,
    cancelToken: cancel,
    options: Options(sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 2)),
    onSendProgress: onProgress == null
        ? null
        : (sent, total) {
            if (total > 0) onProgress(sent / total);
          },
  )).data;

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    return Map.fromEntries(q.entries.where((e) => e.value != null && e.value != ''));
  }

  void close() => dio.close(force: true);
}

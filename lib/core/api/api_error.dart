import 'dart:async';

import 'package:dio/dio.dart';

/// Human-readable error from an API failure, mirroring web `api-error.ts`.
class ApiError implements Exception {
  const new(this.message, {this.status, this.fieldErrors = const {}, this.retryAfter, this.offline = false});

  factory from(Object error, [String fallback = 'Something went wrong.']) {
    if (error is ApiError) return error;

    // `(a, b, c).wait` wraps each failure in [AsyncError] inside a
    // [ParallelWaitError]; unwrap so a 404/timeout is not shown as a
    // generic "Something went wrong".
    if (error is ParallelWaitError) {
      final picked = _pickParallel(error.errors);
      if (picked != null) return ApiError.from(picked, fallback);
    }
    if (error is AsyncError) return ApiError.from(error.error, fallback);

    if (error is DioException) {
      final res = error.response;
      final data = res?.data;
      var message = fallback;
      var fields = <String, List<String>>{};
      if (data is Map) {
        final m = data['message'];
        if (m is String && m.isNotEmpty) {
          message = m.replaceFirst(RegExp(r'^\[(spotify|github)\]\s*', caseSensitive: false), '');
        }
        final errs = data['errors'];
        if (errs is Map) {
          fields = errs.map(
            (k, v) => MapEntry(k.toString(), v is List ? v.map((e) => e.toString()).toList() : [v.toString()]),
          );
        }
      }
      if (res?.statusCode == 429 && message == fallback) {
        message = 'Too many requests. Try again shortly.';
      }
      final offline = res == null;
      if (offline) {
        message = switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout => 'The server took too long to answer.',
          DioExceptionType.connectionError => "Can't reach Nexus. Check your connection.",
          _ => fallback,
        };
      }
      final retry = data is Map ? data['retry_after'] : null;
      return ApiError(
        message,
        status: res?.statusCode,
        fieldErrors: fields,
        retryAfter: retry is num ? retry.toInt() : int.tryParse(res?.headers.value('retry-after') ?? ''),
        offline: offline,
      );
    }
    return ApiError(fallback);
  }

  /// Prefer an HTTP response (e.g. 404) over a bare connection failure when
  /// several parallel requests fail together.
  static Object? _pickParallel(Object? errors) {
    final list = switch (errors) {
      final Iterable<Object?> i => i,
      (final Object? a,) => [a],
      (final Object? a, final Object? b) => [a, b],
      (final Object? a, final Object? b, final Object? c) => [a, b, c],
      (final Object? a, final Object? b, final Object? c, final Object? d) => [a, b, c, d],
      (final Object? a, final Object? b, final Object? c, final Object? d, final Object? e) => [a, b, c, d, e],
      (final Object? a, final Object? b, final Object? c, final Object? d, final Object? e, final Object? f) => [
        a,
        b,
        c,
        d,
        e,
        f,
      ],
      _ => const <Object?>[],
    }.whereType<Object>().map(_unwrap).toList();
    for (final e in list) {
      if (e is DioException && e.response != null) return e;
    }
    for (final e in list) {
      if (e is DioException) return e;
    }
    return list.firstOrNull;
  }

  static Object _unwrap(Object error) => switch (error) {
    AsyncError(:final error) => _unwrap(error),
    ParallelWaitError(:final errors) => _pickParallel(errors) ?? error,
    _ => error,
  };

  final String message;
  final int? status;
  final Map<String, List<String>> fieldErrors;
  final int? retryAfter;

  /// True only when the request never got an HTTP response (timeout / no
  /// route to the API). Unknown errors stay [offline] false so they don't
  /// show as "You're offline".
  final bool offline;

  bool get isOffline => offline;
  bool get isRateLimited => status == 429;
  bool get isNotFound => status == 404;

  /// Integration needs the user to reconnect (expired provider grant).
  bool get isReauth {
    if (status == 409) return true;
    if (status != 401) return false;
    final m = message.toLowerCase();
    return m.contains('re-authorization') || m.contains('reconnect');
  }

  bool get isNotConnected => status == 404 && message.toLowerCase().contains('not connected');

  /// API asked the user to sync (e.g. a GitHub repo missing from the local index).
  bool get suggestsSync => message.toLowerCase().contains('sync');

  String? field(String key) => fieldErrors[key]?.first;

  @override
  String toString() => message;
}

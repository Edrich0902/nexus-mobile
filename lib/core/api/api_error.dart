import 'package:dio/dio.dart';

/// Human-readable error from an API failure, mirroring web `api-error.ts`.
class ApiError implements Exception {
  const new(this.message, {this.status, this.fieldErrors = const {}, this.retryAfter});

  factory from(Object error, [String fallback = 'Something went wrong.']) {
    if (error is ApiError) return error;
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
      if (res == null) {
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
      );
    }
    return ApiError(fallback);
  }

  final String message;
  final int? status;
  final Map<String, List<String>> fieldErrors;
  final int? retryAfter;

  bool get isOffline => status == null;
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

  String? field(String key) => fieldErrors[key]?.first;

  @override
  String toString() => message;
}

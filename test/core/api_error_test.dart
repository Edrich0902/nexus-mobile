import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/api/api_error.dart';

DioException _dio(int? status, {String? message, DioExceptionType type = DioExceptionType.badResponse}) {
  return DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
    response: status == null
        ? null
        : Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: status,
            data: message == null ? null : {'message': message},
          ),
  );
}

void main() {
  test('HTTP 404 is not offline and keeps the API message', () {
    final err = ApiError.from(_dio(404, message: 'Repository not found. Sync GitHub repos and try again.'));
    expect(err.isOffline, isFalse);
    expect(err.isNotFound, isTrue);
    expect(err.suggestsSync, isTrue);
    expect(err.message, contains('Sync GitHub'));
  });

  test('connection failures are offline', () {
    final err = ApiError.from(_dio(null, type: DioExceptionType.connectionError));
    expect(err.isOffline, isTrue);
    expect(err.message, contains("Can't reach Nexus"));
  });

  test('ParallelWaitError unwraps a 404 instead of looking offline', () {
    final notFound = _dio(404, message: 'Repository not found. Sync GitHub repos and try again.');
    final offline = _dio(null, type: DioExceptionType.connectionError);
    final err = ApiError.from(ParallelWaitError((null, null, null), (notFound, offline, notFound)));
    expect(err.isOffline, isFalse);
    expect(err.isNotFound, isTrue);
    expect(err.suggestsSync, isTrue);
  });

  test('ParallelWaitError from .wait unwraps AsyncError-wrapped Dio 404s', () async {
    Future<Never> fail(DioException e) async => throw e;
    final notFound = _dio(404, message: 'Repository not found. Sync GitHub repos and try again.');
    Object? caught;
    try {
      await (fail(notFound), fail(notFound), fail(notFound)).wait;
    } catch (e) {
      caught = e;
    }
    final err = ApiError.from(caught!);
    expect(caught, isA<ParallelWaitError<dynamic, dynamic>>());
    expect(err.isOffline, isFalse);
    expect(err.isNotFound, isTrue);
    expect(err.message, contains('Sync GitHub'));
  });

  test('unknown errors are not labelled offline', () {
    final err = ApiError.from(StateError('boom'));
    expect(err.isOffline, isFalse);
    expect(err.message, 'Something went wrong.');
  });
}

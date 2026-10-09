import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/design/widgets/nx_form.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

PageQuery bookQuery({String q = '', String? status}) => PageQuery('/library/books', {'q': q.trim(), 'status': status});

final bookProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) async {
  return asJson(await ref.watch(apiClientProvider).get('/library/books/$id'));
});

final libraryApiProvider = Provider<LibraryApi>(LibraryApi.new);

class LibraryApi {
  LibraryApi(this._ref);

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);

  Json _changed(Json book, [int? id]) {
    _ref
      ..invalidate(pagedProvider)
      ..invalidate(libraryPulseProvider);
    if (id != null) _ref.invalidate(bookProvider(id));
    return book;
  }

  Future<Json> create(Json payload) async => _changed(asJson(await _api.post('/library/books', data: payload)));

  Future<Json> createFromCatalog(String olWorkKey, Json extra) async =>
      _changed(asJson(await _api.post('/library/books/from-catalog', data: {'ol_work_key': olWorkKey, ...extra})));

  Future<Json> update(int id, Json payload) async =>
      _changed(asJson(await _api.patch('/library/books/$id', data: payload)), id);

  /// Move a book to its next reading status, stamping today's date.
  Future<Json> advance(Json book) {
    final reading = book.str('status') == 'want';
    return update(book.integer('id') ?? 0, {
      'title': book.text('title'),
      'status': reading ? 'reading' : 'read',
      reading ? 'started_at' : 'finished_at': isoDay(DateTime.now()),
    });
  }

  Future<void> remove(int id) async {
    await _api.delete('/library/books/$id');
    _changed(const {});
  }

  Future<List<Json>> searchCatalog(String q, {CancelToken? cancel}) async =>
      asJson(await _api.get('/library/search', query: {'q': q}, cancel: cancel)).list('results');

  /// `{candidates, from_cache, message?}`
  Future<Json> candidates(int id, {String? q}) async =>
      asJson(await _api.get('/library/books/$id/candidates', query: {'q': ?q}));

  Future<Json> match(int id, String olWorkKey) async =>
      _changed(asJson(await _api.post('/library/books/$id/match', data: {'ol_work_key': olWorkKey})), id);

  Future<Json> noMatch(int id) async => _changed(asJson(await _api.post('/library/books/$id/no-match')), id);

  void imageAttached(int id) => _changed(const {}, id);
}

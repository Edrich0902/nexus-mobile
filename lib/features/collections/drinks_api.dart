import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

PageQuery drinkQuery(DrinkKind kind, String q) => PageQuery(kind.apiBase, {'q': q.trim()});

final drinkProvider = FutureProvider.autoDispose.family<Json, (DrinkKind, int)>((ref, key) async {
  final (kind, id) = key;
  return asJson(await ref.watch(apiClientProvider).get('${kind.apiBase}/$id'));
});

/// Gemini model availability (web NexusQuotaBadge). Optional: never errors.
final analysisQuotaProvider = FutureProvider.autoDispose<Json?>((ref) async {
  if (ref.watch(authProvider) is! SignedIn) return null;
  try {
    return asJson(await ref.watch(apiClientProvider).get('/analysis/quota'));
  } on Object {
    return null;
  }
});

final beerStylesProvider = FutureProvider<List<Json>>((ref) async {
  final json = asJson(await ref.watch(apiClientProvider).get('/beer/styles'));
  return json.list('styles');
});

final breweryProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) async {
  return asJson(await ref.watch(apiClientProvider).get('/beer/breweries/$id'));
});

/// Beers linked to one brewery: the API has no brewery filter, so this walks
/// the (capped) first page of the log like the web brewery view.
final breweryBeersProvider = FutureProvider.autoDispose.family<List<Json>, int>((ref, id) async {
  final json = asJson(await ref.watch(apiClientProvider).get('/beer/beers', query: {'per_page': 50}));
  return asJsonList(json['data']).where((b) => b.obj('brewery')?.integer('id') == id).toList();
});

final drinksApiProvider = Provider<DrinksApi>(DrinksApi.new);

class DrinksApi {
  DrinksApi(this._ref);

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);

  void _changed(DrinkKind kind, [int? id]) {
    _ref
      ..invalidate(pagedProvider)
      ..invalidate(foodDrinkDashboardProvider);
    if (id != null) _ref.invalidate(drinkProvider((kind, id)));
  }

  Future<Json> create(DrinkKind kind, Json payload) async {
    final json = asJson(await _api.post(kind.apiBase, data: payload));
    _changed(kind);
    return json;
  }

  Future<Json> update(DrinkKind kind, int id, Json payload) async {
    final json = asJson(await _api.patch('${kind.apiBase}/$id', data: payload));
    _changed(kind, id);
    return json;
  }

  Future<void> remove(DrinkKind kind, int id) async {
    await _api.delete('${kind.apiBase}/$id');
    _changed(kind);
  }

  Future<void> analyse(DrinkKind kind, int id, {bool force = false}) async {
    await _api.post('${kind.apiBase}/$id/analyse', data: {'force': force});
    _ref.invalidate(analysisQuotaProvider);
    _changed(kind, id);
  }

  /// After a label photo lands: refresh the record (the API may start an
  /// analysis on attach).
  void imageAttached(DrinkKind kind, int id) => _changed(kind, id);

  Future<void> addTasting(int wineId, Json payload) async {
    await _api.post('/cellar/wines/$wineId/tastings', data: payload);
    _changed(DrinkKind.wine, wineId);
  }

  Future<void> removeTasting(int wineId, int tastingId) async {
    await _api.delete('/cellar/tastings/$tastingId');
    _changed(DrinkKind.wine, wineId);
  }

  Future<List<Json>> searchBreweries(String q) async =>
      asJson(await _api.get('/beer/breweries/search', query: {'q': q})).list('results');

  Future<Json> importBrewery(String obdbId) async =>
      asJson(await _api.post('/beer/breweries/import', data: {'obdb_id': obdbId}));

  Future<Json> createBrewery(Json payload) async => asJson(await _api.post('/beer/breweries', data: payload));
}

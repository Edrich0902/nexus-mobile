import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

PageQuery recipeQuery({String q = '', bool favourites = false}) =>
    PageQuery('/kitchen/recipes', {'q': q.trim(), 'favourite': favourites ? 1 : null});

final recipeProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) async {
  return asJson(await ref.watch(apiClientProvider).get('/kitchen/recipes/$id'));
});

/// A TheMealDB meal (imported on first view by the API).
final mealProvider = FutureProvider.autoDispose.family<Json, String>((ref, mealdbId) async {
  final json = asJson(await ref.watch(apiClientProvider).get('/kitchen/meals/$mealdbId'));
  return json.obj('meal') ?? json;
});

final kitchenFiltersProvider = FutureProvider<Json>((ref) async {
  return asJson(await ref.watch(apiClientProvider).get('/kitchen/filters'));
});

/// Discover grid: a text search, or a category/cuisine browse.
final discoverProvider = FutureProvider.autoDispose.family<List<Json>, ({String q, String? category, String? area})>((
  ref,
  f,
) async {
  final api = ref.watch(apiClientProvider);
  final json = f.q.isNotEmpty
      ? await api.get('/kitchen/search', query: {'q': f.q})
      : await api.get('/kitchen/browse', query: {'category': f.category, 'area': f.area});
  return asJson(json).list('results');
});

final pairingsProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  if (ref.watch(authProvider) is! SignedIn) return const [];
  return asJsonList(await ref.watch(apiClientProvider).get('/food-drink/pairings'));
});

final suggestionsProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  final json = asJson(await ref.watch(apiClientProvider).get('/food-drink/suggestions', query: {'limit': 10}));
  return json.list('suggestions');
});

final kitchenApiProvider = Provider<KitchenApi>(KitchenApi.new);

class KitchenApi {
  KitchenApi(this._ref);

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);

  Json _changed(Json recipe, [int? id]) {
    _ref
      ..invalidate(pagedProvider)
      ..invalidate(foodDrinkDashboardProvider);
    if (id != null) _ref.invalidate(recipeProvider(id));
    return recipe;
  }

  Future<Json> random() async {
    final json = asJson(await _api.get('/kitchen/random'));
    return json.obj('meal') ?? json;
  }

  Future<Json> save(String mealdbId) async =>
      _changed(asJson(await _api.post('/kitchen/recipes', data: {'mealdb_id': mealdbId})));

  Future<Json> update(int id, Json payload) async =>
      _changed(asJson(await _api.patch('/kitchen/recipes/$id', data: payload)), id);

  Future<Json> markCooked(int id) async => _changed(asJson(await _api.post('/kitchen/recipes/$id/cooked')), id);

  Future<void> remove(int id) async {
    await _api.delete('/kitchen/recipes/$id');
    _changed(const {});
  }

  void imageAttached(int id) => _changed(const {}, id);

  Future<void> createPairing(Json payload) async {
    await _api.post('/food-drink/pairings', data: payload);
    _ref
      ..invalidate(pairingsProvider)
      ..invalidate(suggestionsProvider)
      ..invalidate(foodDrinkDashboardProvider);
  }

  Future<void> deletePairing(int id) async {
    await _api.delete('/food-drink/pairings/$id');
    _ref
      ..invalidate(pairingsProvider)
      ..invalidate(foodDrinkDashboardProvider);
  }
}

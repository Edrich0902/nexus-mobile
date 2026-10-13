import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';

/// A paginated collection endpoint plus its filters. Value-equal so it can
/// key a provider family; empty filters are dropped.
@immutable
class PageQuery {
  new(this.path, [Map<String, Object?> params = const {}])
    : params = Map.unmodifiable({
        for (final e in params.entries)
          if (e.value != null && e.value != '' && e.value != false) e.key: e.value,
      });

  final String path;
  final Map<String, Object?> params;

  String get _canonical {
    final keys = params.keys.toList()..sort();
    return '$path?${keys.map((k) => '$k=${params[k]}').join('&')}';
  }

  @override
  bool operator ==(Object other) => other is PageQuery && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;
}

@immutable
class PagedState {
  const new({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
    this.loadingMore = false,
  });

  final List<Json> items;
  final int page;
  final int lastPage;
  final int total;
  final bool loadingMore;

  bool get hasMore => page < lastPage;
  int get remaining => total - items.length;

  PagedState copyWith({List<Json>? items, int? page, int? lastPage, int? total, bool? loadingMore}) => PagedState(
    items: items ?? this.items,
    page: page ?? this.page,
    lastPage: lastPage ?? this.lastPage,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// First page on build, `loadMore()` appends the next. Every collection index
/// (wines, beers, spirits, books, recipes) uses this.
final pagedProvider = AsyncNotifierProvider.autoDispose.family<PagedList, PagedState, PageQuery>(PagedList.new);

class PagedList extends AsyncNotifier<PagedState> {
  new(this.query);

  final PageQuery query;

  Future<Page<Json>> _fetch(int page) async {
    final api = ref.read(apiClientProvider);
    final json = asJson(await api.get(query.path, query: {...query.params, 'page': page}));
    return Page.fromJson(json, (j) => j);
  }

  @override
  Future<PagedState> build() async {
    if (ref.watch(authProvider) is! SignedIn) return const PagedState(items: [], page: 1, lastPage: 1, total: 0);
    final p = await _fetch(1);
    return PagedState(items: p.items, page: p.currentPage, lastPage: p.lastPage, total: p.total);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await _fetch(s.page + 1);
      final seen = {for (final i in s.items) i['id']};
      state = AsyncData(
        s.copyWith(
          items: [...s.items, ...p.items.where((i) => !seen.contains(i['id']))],
          page: p.currentPage,
          lastPage: p.lastPage,
          total: p.total,
          loadingMore: false,
        ),
      );
    } on Object {
      state = AsyncData(s.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/features/home/hub_api.dart';

class ActivityState {
  const ActivityState({this.items = const [], this.cursor, this.loadingMore = false});

  final List<Json> items;
  final String? cursor;
  final bool loadingMore;
}

/// Cursor-paginated `/activity` (web hub store).
final activityProvider = AsyncNotifierProvider<ActivityController, ActivityState>(ActivityController.new);

class ActivityController extends AsyncNotifier<ActivityState> {
  static const pageSize = 20;

  @override
  Future<ActivityState> build() async {
    if (ref.watch(authProvider) is! SignedIn) return const ActivityState();
    final page = await ref.read(hubApiProvider).activity(limit: pageSize);
    return ActivityState(items: page.list('data'), cursor: page.str('next_cursor'));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.cursor == null || current.loadingMore) return;
    state = AsyncData(ActivityState(items: current.items, cursor: current.cursor, loadingMore: true));
    try {
      final page = await ref.read(hubApiProvider).activity(cursor: current.cursor, limit: pageSize);
      state = AsyncData(
        ActivityState(items: [...current.items, ...page.list('data')], cursor: page.str('next_cursor')),
      );
    } on Object {
      state = AsyncData(current);
    }
  }
}

const _moduleMeta = <String, (SectionKey, String)>{
  'listening': (SectionKey.listening, 'Listening'),
  'cellar': (SectionKey.cellar, 'Cellar'),
  'beer': (SectionKey.beer, 'Beer'),
  'spirits': (SectionKey.spirits, 'Spirits'),
  'kitchen': (SectionKey.kitchen, 'Kitchen'),
  'library': (SectionKey.library, 'Library'),
  'code': (SectionKey.code, 'Code'),
};

const _verbs = <String, String>{
  'listening.block': 'Session',
  'wine.added': 'Added',
  'wine.tasted': 'Tasted',
  'beer.added': 'Logged',
  'spirit.added': 'Added',
  'recipe.saved': 'Saved',
  'recipe.cooked': 'Cooked',
  'book.added': 'Shelved',
  'book.started': 'Started',
  'book.finished': 'Finished',
  'repo.pushed': 'Pushed',
};

String? activityKind(Json e) => _moduleMeta[e.str('module')]?.$2;
String? activityVerb(Json e) => _verbs[e.str('type')];

Color activityColour(Json e) {
  final module = e.str('module');
  final section = _moduleMeta[module]?.$1 ?? SectionKey.home;
  return module == 'code' || module == 'cellar' ? section.ambient.acc : section.field.bg;
}

/// Subject → app path (web `streamTo`).
String? activityPath(Json e) {
  final subject = e.obj('subject');
  final id = subject?.str('id');
  switch (subject?.str('type')) {
    case 'cellar_wine':
      return '/cellar/wines/$id';
    case 'beer_beer':
      return '/beer/beers/$id';
    case 'spirit_spirit':
      return '/spirits/$id';
    case 'kitchen_recipe':
      return '/kitchen/recipes/$id';
    case 'library_book':
      return '/library/books/$id';
  }
  if (e.str('module') == 'listening') return '/spotify';
  final repo = e.obj('meta')?.str('repo');
  if (e.str('module') == 'code' && repo != null && repo.contains('/')) return '/github/$repo';
  return null;
}

List<String> activityChips(Json e) {
  final m = e.obj('meta') ?? const {};
  final tracks = m.integer('tracks');
  final minutes = m.integer('minutes');
  final rating = m.number('rating');
  final abv = m.number('abv');
  final cooked = m.integer('cooked_count');
  return [
    if (tracks != null) '$tracks track${tracks == 1 ? '' : 's'}',
    if (minutes != null && minutes > 0) '$minutes min',
    if (rating != null) '★ ${rating % 1 == 0 ? rating.toInt() : rating}',
    if (abv != null) '$abv%',
    ?m.str('occasion'),
    ?m.str('language'),
    if (cooked != null && cooked > 1) '$cooked× cooked',
  ];
}

/// Today / Yesterday / Earlier groups, preserving order.
List<(String, List<Json>)> groupByDay(List<Json> events, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final groups = <(String, List<Json>)>[];
  for (final e in events) {
    final at = e.date('occurred_at') ?? n;
    final day = DateTime(at.year, at.month, at.day);
    final label = day == today
        ? 'Today'
        : day == yesterday
        ? 'Yesterday'
        : 'Earlier';
    if (groups.isNotEmpty && groups.last.$1 == label) {
      groups.last.$2.add(e);
    } else {
      groups.add((label, [e]));
    }
  }
  return groups;
}

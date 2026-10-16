import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/providers.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/features/listening/player.dart';

final foodDrinkDashboardProvider = softJsonProvider('/food-drink/dashboard');
final libraryPulseProvider = softJsonProvider('/library/pulse');
final f1HomeProvider = softJsonProvider('/f1/home');
final sportsHomeProvider = softJsonProvider('/sports/home');
final githubStatusProvider = softJsonProvider('/github/status');
final githubPulseProvider = softJsonProvider('/github/pulse');
final spotifyTasteProvider = softJsonProvider('/spotify/taste');

class HomeField {
  const new({
    required this.key,
    required this.section,
    required this.label,
    required this.value,
    required this.to,
    this.aside,
    this.sub,
    this.span = 1,
    this.valueSize = 44,
    this.tint = false,
  });

  final String key;
  final SectionKey section;
  final String label;
  final String value;
  final String to;
  final String? aside;
  final String? sub;
  final int span;
  final double valueSize;
  final bool tint;
}

class HomeUpcoming {
  const new({
    required this.key,
    required this.when,
    required this.section,
    required this.kind,
    required this.title,
    required this.to,
    this.meta,
  });

  final String key;
  final DateTime when;
  final SectionKey section;
  final String kind;
  final String title;
  final String to;
  final String? meta;
}

class HomeModules {
  const new({required this.loading, required this.fields, required this.summary, required this.upcoming});

  final bool loading;
  final List<HomeField> fields;
  final List<(String, bool)> summary;
  final List<HomeUpcoming> upcoming;
}

final _fmt = NumberFormat.decimalPattern();
String _n(num? n) => _fmt.format(n ?? 0);
String _plural(num n, String word) => '${_n(n)} $word${n == 1 ? '' : 's'}';

int? daysUntil(DateTime? at) {
  if (at == null) return null;
  return (at.difference(DateTime.now()).inMinutes / (60 * 24)).ceil();
}

String shortDay(DateTime at) {
  final days = daysUntil(at) ?? 99;
  if (days <= 0) return DateFormat('HH:mm').format(at);
  if (days < 7) return DateFormat('EEE').format(at);
  return DateFormat('d MMM').format(at);
}

/// Module pulses → colour fields, serif summary and "coming up"
/// (web `useHomeModules`).
final homeModulesProvider = Provider<HomeModules>((ref) {
  final deps = [
    ref.watch(foodDrinkDashboardProvider),
    ref.watch(libraryPulseProvider),
    ref.watch(f1HomeProvider),
    ref.watch(sportsHomeProvider),
    ref.watch(githubStatusProvider),
    ref.watch(githubPulseProvider),
    ref.watch(spotifyTasteProvider),
  ];
  final loading = deps.any((d) => d.isLoading && !d.hasValue);
  final dash = deps[0].value ?? const {};
  final library = deps[1].value ?? const {};
  final f1 = deps[2].value ?? const {};
  final sports = deps[3].value ?? const {};
  final githubConnected = deps[4].value?.flag('connected') ?? false;
  final pulls = deps[5].value?.list('open_pulls') ?? const [];
  final spotifyConnected = ref.watch(spotifyStatusProvider).value?.flag('connected') ?? false;
  final taste = deps[6].value?.obj('summary');

  final counts = dash.obj('counts') ?? const {};
  final reading = library.list('reading').firstOrNull;
  final meeting = f1.obj('next_meeting');
  // Skip kickoffs already in the past (stale snapshot until API rebuilds).
  final now = DateTime.now();
  final fixture = sports.list('upcoming').where((e) {
    final at = e.date('starts_at');
    return at == null || !at.isBefore(now);
  }).firstOrNull;

  final fields = <HomeField>[
    if (spotifyConnected && taste != null)
      HomeField(
        key: 'listening',
        section: SectionKey.listening,
        label: 'Listening this week',
        aside: taste.str('top_genre'),
        value: _n(taste.integer('plays_last_7d')),
        sub: 'plays · ${_n(taste.integer('unique_tracks_last_7d'))} different tracks',
        span: 2,
        valueSize: 84,
        to: '/spotify',
      )
    else
      HomeField(
        key: 'listening',
        section: SectionKey.listening,
        label: 'Listening',
        value: spotifyConnected ? '—' : 'Connect',
        sub: spotifyConnected ? 'Gathering your week' : 'Link Spotify to see your week',
        span: 2,
        valueSize: 56,
        tint: true,
        to: '/spotify',
      ),
    HomeField(
      key: 'cellar',
      section: SectionKey.cellar,
      label: 'Cellar',
      aside: dash.list('recent_wines').firstOrNull?.str('name'),
      value: _n(counts.integer('wines')),
      sub: counts.integer('wines') == 1 ? 'bottle' : 'bottles',
      to: '/cellar',
    ),
    () {
      final days = daysUntil(meeting?.date('date_start'));
      return HomeField(
        key: 'f1',
        section: SectionKey.f1,
        label: 'Next race',
        value: days == null
            ? '—'
            : days <= 0
            ? 'Now'
            : '${days}d',
        sub: meeting?.str('meeting_name') ?? 'Season break',
        to: '/f1',
      );
    }(),
    HomeField(
      key: 'beer',
      section: SectionKey.beer,
      label: 'Beer',
      value: _n(counts.integer('beers')),
      sub: 'logged',
      to: '/beer',
    ),
    HomeField(
      key: 'code',
      section: SectionKey.code,
      label: 'Code',
      value: githubConnected ? '${pulls.length}' : '—',
      sub: githubConnected ? (pulls.firstOrNull?.str('title') ?? 'No open pull requests') : 'Connect GitHub',
      to: pulls.isNotEmpty ? '/github/pulls' : '/github',
    ),
    HomeField(
      key: 'library',
      section: SectionKey.library,
      label: reading != null ? 'Reading' : 'Library',
      value: _n(library.obj('counts')?.integer('reading')),
      sub:
          reading?.str('title') ??
          switch (library.obj('counts')?.integer('total')) {
            1 => '1 book',
            final total => '${_n(total)} books',
          },
      to: reading != null ? '/library/books/${reading.integer('id')}' : '/library',
    ),
    HomeField(
      key: 'spirits',
      section: SectionKey.spirits,
      label: 'Spirits',
      value: _n(counts.integer('spirits')),
      sub: 'on the shelf',
      to: '/spirits',
    ),
    HomeField(
      key: 'kitchen',
      section: SectionKey.kitchen,
      label: 'Recipes',
      value: _n(counts.integer('recipes')),
      sub: 'saved',
      to: '/kitchen',
    ),
    HomeField(
      key: 'food-drink',
      section: SectionKey.foodDrink,
      label: 'Pairings',
      value: _n(counts.integer('pairings')),
      sub: 'food & drink',
      to: '/food-drink',
    ),
    HomeField(
      key: 'sports',
      section: SectionKey.sports,
      label: 'Next fixture',
      value: fixture?.date('starts_at') != null ? shortDay(fixture!.date('starts_at')!) : '—',
      sub: fixture?.str('name') ?? 'Nothing scheduled',
      valueSize: 34,
      to: fixture != null ? '/sports/${fixture.text('sport_slug', 'football')}' : '/sports/football',
    ),
  ];

  final clauses = <List<(String, bool)>>[
    if ((taste?.integer('plays_last_7d') ?? 0) > 0)
      [('played ', false), (_plural(taste!.integer('plays_last_7d')!, 'track'), true), (' this week', false)],
    if ((counts.integer('wines') ?? 0) > 0)
      [('have ', false), (_plural(counts.integer('wines')!, 'bottle'), true), (' in the cellar', false)],
    if (reading != null) [('are reading ', false), (reading.text('title'), true)],
    if (pulls.isNotEmpty) [('have ', false), (_plural(pulls.length, 'pull request'), true), (' open', false)],
  ];
  final summary = <(String, bool)>[];
  if (clauses.isNotEmpty) {
    summary.add(('You ', false));
    for (var i = 0; i < clauses.length; i++) {
      if (i > 0) summary.add((i == clauses.length - 1 ? ' and ' : ', ', false));
      summary.addAll(clauses[i]);
    }
    summary.add(('.', false));
  }

  final upcoming = <HomeUpcoming>[
    if (meeting?.date('date_start') case final at?)
      HomeUpcoming(
        key: 'f1:${meeting!.str('meeting_key')}',
        when: at,
        section: SectionKey.f1,
        kind: 'F1',
        meta: meeting.str('circuit_short_name') ?? meeting.str('location'),
        title: meeting.text('meeting_name'),
        to: '/f1',
      ),
    if (fixture?.date('starts_at') case final at?)
      HomeUpcoming(
        key: 'sports:${fixture!.str('id')}',
        when: at,
        section: SectionKey.sports,
        kind: fixture.str('league_name') ?? 'Sports',
        meta: fixture.str('venue'),
        title: fixture.text('name'),
        to: '/sports/${fixture.text('sport_slug', 'football')}',
      ),
  ]..sort((a, b) => a.when.compareTo(b.when));

  return HomeModules(loading: loading, fields: fields, summary: summary, upcoming: upcoming.take(3).toList());
});

void refreshHomeModules(WidgetRef ref) {
  [
    foodDrinkDashboardProvider,
    libraryPulseProvider,
    f1HomeProvider,
    sportsHomeProvider,
    githubStatusProvider,
    githubPulseProvider,
    spotifyTasteProvider,
  ].forEach(ref.invalidate);
}

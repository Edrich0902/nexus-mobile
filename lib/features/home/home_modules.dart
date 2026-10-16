import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/providers.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/features/home/home_cycle.dart';
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
    required this.slideId,
    this.aside,
    this.sub,
    this.span = 1,
    this.valueSize = 44,
    this.tint = false,
    this.imageUrl,
    this.imageMedia,
  });

  final String key;
  final SectionKey section;
  final String label;
  final String value;
  final String to;

  /// Stable id for the current slide — drives the field flip animation.
  final String slideId;
  final String? aside;
  final String? sub;
  final int span;
  final double valueSize;
  final bool tint;
  final String? imageUrl;
  final MediaImage? imageMedia;
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

class _Slide {
  const new({
    required this.id,
    required this.label,
    required this.value,
    required this.to,
    this.aside,
    this.sub,
    this.valueSize = 44,
    this.tint = false,
    this.imageUrl,
    this.imageMedia,
  });

  final String id;
  final String label;
  final String value;
  final String to;
  final String? aside;
  final String? sub;
  final double valueSize;
  final bool tint;
  final String? imageUrl;
  final MediaImage? imageMedia;
}

final _fmt = NumberFormat.decimalPattern();
String _n(num? n) => _fmt.format(n ?? 0);
String _plural(num n, String word) => '${_n(n)} $word${n == 1 ? '' : 's'}';

/// Soft ellipsis — keeps titles readable in the field.
String _clip(String? raw, [int max = 36]) {
  final t = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1).trimRight()}…';
}

String? _img(Json item) {
  final url = item.str('image_url');
  if (url != null && url.isNotEmpty) return url;
  return item.obj('media')?.str('url');
}

MediaImage? _media(Json item) {
  final m = MediaImage.of(item);
  if (m != null && !m.isEmpty) return m;
  final url = _img(item);
  return url == null ? null : MediaImage(url: url);
}

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

String _sportLabel(String? slug) => switch (slug) {
  'football' => 'Football',
  'tennis' => 'Tennis',
  'rugby' => 'Rugby',
  'golf' => 'Golf',
  'darts' => 'Darts',
  'field-hockey' => 'Field Hockey',
  null || '' => 'Sports',
  _ => slug,
};

String _peakLabel(String? bucket) => switch (bucket) {
  'morning' => 'Mornings',
  'afternoon' => 'Afternoons',
  'evening' => 'Evenings',
  'night' => 'Nights',
  _ => bucket ?? 'Listening',
};

HomeField _field(String key, SectionKey section, _Slide slide, {int span = 1}) => HomeField(
  key: key,
  section: section,
  label: slide.label,
  value: slide.value,
  sub: slide.sub,
  aside: slide.aside,
  valueSize: slide.valueSize,
  tint: slide.tint,
  span: span,
  to: slide.to,
  imageUrl: slide.imageUrl,
  imageMedia: slide.imageMedia,
  slideId: '$key:${slide.id}',
);

/// Home board: slides rotate on a staggered cadence with flip + media.
final homeModulesProvider = Provider<HomeModules>((ref) => _homeModules(ref, cycling: true));

/// More tab: static glance counts only — no cycle clock, no media faces.
final moreModulesProvider = Provider<HomeModules>((ref) => _homeModules(ref, cycling: false));

HomeModules _homeModules(Ref ref, {required bool cycling}) {
  final now = cycling ? (ref.watch(homeCycleClockProvider).value ?? DateTime.now()) : DateTime.now();
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
  final pulse = deps[5].value ?? const {};
  final pulls = pulse.list('open_pulls');
  final merged = pulse.list('merged_pulls');
  final commits = pulse.list('commits');
  final spotifyConnected = ref.watch(spotifyStatusProvider).value?.flag('connected') ?? false;
  final tastePayload = deps[6].value ?? const {};
  final taste = tastePayload.obj('summary');
  final counts = dash.obj('counts') ?? const {};

  final fixtures = sports.list('upcoming').where((e) {
    final at = e.date('starts_at');
    return at == null || !at.isBefore(now);
  }).toList();

  // Glance pins the summary/count face (first slide); home cycles through all.
  _Slide pick(String key, List<_Slide> slides) => cycling ? cycleAt(slides, now, key) : slides.first;

  HomeField field(String key, SectionKey section, _Slide slide, {int span = 1}) {
    if (!cycling) {
      // More: no cover art, no flip key — equal-height glance tiles.
      return HomeField(
        key: key,
        section: section,
        label: slide.label,
        value: slide.value,
        sub: slide.sub,
        aside: slide.aside,
        valueSize: slide.valueSize,
        tint: slide.tint,
        span: span,
        to: slide.to,
        slideId: key,
      );
    }
    return _field(key, section, slide, span: span);
  }

  final fields = <HomeField>[
    field(
      'listening',
      SectionKey.listening,
      pick('listening', _listeningSlides(spotifyConnected, tastePayload, taste)),
      span: 2,
    ),
    field('cellar', SectionKey.cellar, pick('cellar', _cellarSlides(counts, dash.list('recent_wines')))),
    field('f1', SectionKey.f1, pick('f1', _f1Slides(f1))),
    field('beer', SectionKey.beer, pick('beer', _beerSlides(counts, dash.list('recent_beers')))),
    field('code', SectionKey.code, pick('code', _codeSlides(githubConnected, pulls, merged, commits))),
    field('library', SectionKey.library, pick('library', _librarySlides(library))),
    field('spirits', SectionKey.spirits, pick('spirits', _spiritsSlides(counts, dash.list('recent_spirits')))),
    field('kitchen', SectionKey.kitchen, pick('kitchen', _kitchenSlides(counts, dash.list('top_recipes')))),
    field(
      'food-drink',
      SectionKey.foodDrink,
      pick('food-drink', _pairingSlides(counts, dash.list('recent_pairings'), dash.list('suggestions'))),
    ),
    field('sports', SectionKey.sports, pick('sports', _sportsSlides(fixtures))),
  ];

  final clauses = <List<(String, bool)>>[
    if ((taste?.integer('plays_last_7d') ?? 0) > 0)
      [('played ', false), (_plural(taste!.integer('plays_last_7d')!, 'track'), true), (' this week', false)],
    if ((counts.integer('wines') ?? 0) > 0)
      [('have ', false), (_plural(counts.integer('wines')!, 'bottle'), true), (' in the cellar', false)],
    if (library.list('reading').firstOrNull case final reading?)
      [('are reading ', false), (reading.text('title'), true)],
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

  final meeting = f1.obj('next_meeting');
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
    for (final fixture in fixtures.take(3))
      if (fixture.date('starts_at') case final at?)
        HomeUpcoming(
          key: 'sports:${fixture.str('id')}',
          when: at,
          section: SectionKey.sports,
          kind: fixture.str('league_name') ?? _sportLabel(fixture.str('sport_slug')),
          meta: fixture.str('venue'),
          title: fixture.text('name'),
          to: '/sports/${fixture.text('sport_slug', 'football')}',
        ),
  ]..sort((a, b) => a.when.compareTo(b.when));

  return HomeModules(loading: loading, fields: fields, summary: summary, upcoming: upcoming.take(4).toList());
}

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

// ── Slide builders ──────────────────────────────────────────────────────────

List<_Slide> _listeningSlides(bool connected, Json tastePayload, Json? taste) {
  if (!connected) {
    return const [
      _Slide(
        id: 'connect',
        label: 'Listening',
        value: 'Connect',
        sub: 'Link Spotify to see your week',
        valueSize: 44,
        tint: true,
        to: '/spotify',
      ),
    ];
  }
  final slides = <_Slide>[];
  final plays = taste?.integer('plays_last_7d');
  if (taste != null && (plays ?? 0) > 0) {
    slides.add(
      _Slide(
        id: 'week',
        label: 'Listening this week',
        aside: taste.str('top_genre'),
        value: _n(plays),
        sub: 'plays · ${_n(taste.integer('unique_tracks_last_7d'))} tracks',
        valueSize: 72,
        to: '/spotify',
      ),
    );
  }
  final genre = taste?.str('top_genre');
  if (genre != null && genre.isNotEmpty) {
    slides.add(
      _Slide(id: 'genre', label: 'Top genre', value: _clip(genre, 22), sub: 'this week', valueSize: 28, to: '/spotify'),
    );
  }
  for (final (i, entry) in tastePayload.list('on_repeat').take(2).indexed) {
    final track = entry.obj('track');
    final name = track?.str('name');
    if (name == null || name.isEmpty) continue;
    final artists = track?.list('artists').map((a) => a.str('name')).whereType<String>().join(', ');
    slides.add(
      _Slide(
        id: 'repeat-$i',
        label: 'On repeat',
        value: _clip(name, 28),
        sub: [
          if (entry.integer('play_count') case final c?) '$c×',
          if (artists != null && artists.isNotEmpty) _clip(artists, 28),
        ].join(' · '),
        valueSize: 26,
        imageUrl: track?.str('album_image_url') ?? track?.str('image_url'),
        imageMedia: () {
          final u = track?.str('album_image_url') ?? track?.str('image_url');
          return u == null ? null : MediaImage(url: u);
        }(),
        to: '/spotify',
      ),
    );
  }
  if (taste?.str('peak_bucket') case final peak?) {
    slides.add(
      _Slide(
        id: 'peak',
        label: 'Peak listening',
        value: _peakLabel(peak),
        sub: 'your usual window',
        valueSize: 28,
        to: '/spotify',
      ),
    );
  }
  if (slides.isEmpty) {
    return const [
      _Slide(
        id: 'empty',
        label: 'Listening',
        value: '—',
        sub: 'Gathering your week',
        valueSize: 44,
        tint: true,
        to: '/spotify',
      ),
    ];
  }
  return slides;
}

List<_Slide> _cellarSlides(Json counts, List<Json> wines) {
  final n = counts.integer('wines') ?? 0;
  final slides = <_Slide>[
    _Slide(id: 'count', label: 'Cellar', value: _n(n), sub: n == 1 ? 'bottle' : 'bottles', to: '/cellar'),
  ];
  for (final (i, w) in wines.take(4).indexed) {
    final name = w.str('name');
    if (name == null || name.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'wine-$i',
        label: 'Recent bottle',
        value: _clip(name, 28),
        sub: [w.str('producer_name'), if (w.integer('vintage') case final v?) '$v'].whereType<String>().join(' · '),
        valueSize: 24,
        imageUrl: _img(w),
        imageMedia: _media(w),
        to: '/cellar/wines/${w.integer('id') ?? w.str('id')}',
      ),
    );
  }
  return slides;
}

List<_Slide> _beerSlides(Json counts, List<Json> beers) {
  final n = counts.integer('beers') ?? 0;
  final slides = <_Slide>[_Slide(id: 'count', label: 'Beer', value: _n(n), sub: 'logged', to: '/beer')];
  for (final (i, b) in beers.take(4).indexed) {
    final name = b.str('name');
    if (name == null || name.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'beer-$i',
        label: 'Recent beer',
        value: _clip(name, 28),
        sub: b.obj('brewery')?.str('name') ?? (b.number('rating') != null ? '★ ${b.number('rating')}' : null),
        valueSize: 24,
        imageUrl: _img(b),
        imageMedia: _media(b),
        to: '/beer/beers/${b.integer('id') ?? b.str('id')}',
      ),
    );
  }
  return slides;
}

List<_Slide> _spiritsSlides(Json counts, List<Json> spirits) {
  final n = counts.integer('spirits') ?? 0;
  final slides = <_Slide>[_Slide(id: 'count', label: 'Spirits', value: _n(n), sub: 'on the shelf', to: '/spirits')];
  for (final (i, s) in spirits.take(4).indexed) {
    final name = s.str('name');
    if (name == null || name.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'spirit-$i',
        label: 'Recent spirit',
        value: _clip(name, 28),
        sub: [s.str('producer'), s.str('category')].whereType<String>().join(' · '),
        valueSize: 24,
        imageUrl: _img(s),
        imageMedia: _media(s),
        to: '/spirits/${s.integer('id') ?? s.str('id')}',
      ),
    );
  }
  return slides;
}

List<_Slide> _kitchenSlides(Json counts, List<Json> recipes) {
  final n = counts.integer('recipes') ?? 0;
  final slides = <_Slide>[_Slide(id: 'count', label: 'Recipes', value: _n(n), sub: 'saved', to: '/kitchen')];
  for (final (i, r) in recipes.take(4).indexed) {
    final name = r.obj('meal')?.str('name') ?? r.str('name');
    if (name == null || name.isEmpty) continue;
    final id = r.integer('id') ?? r.str('id');
    slides.add(
      _Slide(
        id: 'recipe-$i',
        label: 'Top recipe',
        value: _clip(name, 28),
        sub: [
          if (r.number('rating') case final rating?) '★ $rating',
          if (r.integer('cooked_count') case final c? when c > 0) '$c×',
        ].join(' · '),
        valueSize: 24,
        imageUrl: _img(r) ?? r.obj('meal')?.str('thumb_url'),
        imageMedia: _media(r) ??
            switch (r.obj('meal')?.str('thumb_url')) {
              final u? when u.isNotEmpty => MediaImage(url: u),
              _ => null,
            },
        to: id == null ? '/kitchen' : '/kitchen/recipes/$id',
      ),
    );
  }
  return slides;
}

List<_Slide> _pairingSlides(Json counts, List<Json> pairings, List<Json> suggestions) {
  final n = counts.integer('pairings') ?? 0;
  final slides = <_Slide>[_Slide(id: 'count', label: 'Pairings', value: _n(n), sub: 'food & drink', to: '/food-drink')];
  for (final (i, p) in pairings.take(3).indexed) {
    final recipe = p.str('recipe_name');
    final drink = p.str('drinkable_name') ?? p.str('drink_name');
    final title = recipe ?? drink;
    if (title == null || title.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'pair-$i',
        label: 'Recent pairing',
        value: _clip(title, 26),
        sub: [if (recipe != null && drink != null) _clip(drink, 24), p.str('verdict')].whereType<String>().join(' · '),
        valueSize: 24,
        to: '/food-drink',
      ),
    );
  }
  for (final (i, s) in suggestions.take(2).indexed) {
    final title = s.str('recipe_name') ?? s.str('title') ?? s.str('name');
    if (title == null || title.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'suggest-$i',
        label: 'Try pairing',
        value: _clip(title, 26),
        sub: s.str('drink_name'),
        valueSize: 24,
        to: '/food-drink',
      ),
    );
  }
  return slides;
}

List<_Slide> _librarySlides(Json library) {
  final counts = library.obj('counts') ?? const {};
  final reading = library.list('reading');
  final recent = library.list('recent');
  final slides = <_Slide>[
    _Slide(
      id: 'count',
      label: reading.isNotEmpty ? 'Reading' : 'Library',
      value: _n(counts.integer('reading')),
      sub: switch (counts.integer('total')) {
        1 => '1 book',
        final total => '${_n(total)} books',
      },
      to: reading.firstOrNull != null
          ? '/library/books/${reading.first.integer('id') ?? reading.first.str('id')}'
          : '/library',
    ),
  ];
  for (final (i, b) in reading.take(3).indexed) {
    final title = b.str('title');
    if (title == null || title.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'reading-$i',
        label: 'Currently reading',
        value: _clip(title, 28),
        sub: b.str('authors') ?? b.str('author'),
        valueSize: 24,
        imageUrl: _img(b),
        imageMedia: _media(b),
        to: '/library/books/${b.integer('id') ?? b.str('id')}',
      ),
    );
  }
  for (final (i, b) in recent.take(2).indexed) {
    if (reading.any((r) => r.integer('id') == b.integer('id') && r.str('id') == b.str('id'))) continue;
    final title = b.str('title');
    if (title == null || title.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'recent-$i',
        label: 'Recent book',
        value: _clip(title, 28),
        sub: b.str('authors') ?? b.str('author') ?? b.str('status'),
        valueSize: 24,
        imageUrl: _img(b),
        imageMedia: _media(b),
        to: '/library/books/${b.integer('id') ?? b.str('id')}',
      ),
    );
  }
  return slides;
}

List<_Slide> _codeSlides(bool connected, List<Json> pulls, List<Json> merged, List<Json> commits) {
  if (!connected) {
    return const [_Slide(id: 'connect', label: 'Code', value: '—', sub: 'Connect GitHub', to: '/github')];
  }
  final slides = <_Slide>[
    _Slide(
      id: 'open',
      label: 'Open PRs',
      value: '${pulls.length}',
      sub: pulls.isEmpty ? 'Nothing waiting' : 'across your repos',
      to: pulls.isNotEmpty ? '/github/pulls' : '/github',
    ),
  ];
  for (final (i, p) in pulls.take(3).indexed) {
    final title = p.str('title');
    if (title == null || title.isEmpty) continue;
    final repo = p.obj('repository')?.str('name') ?? p.obj('repository')?.str('full_name');
    final num = p.integer('number');
    slides.add(
      _Slide(
        id: 'pr-$i',
        label: repo ?? 'Pull request',
        value: num != null ? '#$num' : _clip(title, 18),
        sub: _clip(title, 40),
        valueSize: 36,
        to: () {
          final owner = p.obj('repository')?.str('owner') ?? p.str('owner');
          final name = p.obj('repository')?.str('name') ?? p.str('name');
          if (owner != null && name != null && num != null) return '/github/$owner/$name/pulls/$num';
          return '/github/pulls';
        }(),
      ),
    );
  }
  for (final (i, p) in merged.take(2).indexed) {
    final title = p.str('title');
    if (title == null || title.isEmpty) continue;
    slides.add(
      _Slide(
        id: 'merged-$i',
        label: 'Merged',
        value: _clip(title, 26),
        sub: p.obj('repository')?.str('full_name'),
        valueSize: 22,
        to: '/github/pulls',
      ),
    );
  }
  for (final (i, c) in commits.take(2).indexed) {
    final message = (c.str('message') ?? c.str('commit_message') ?? c.str('title') ?? '').split('\n').first.trim();
    if (message.isEmpty) continue;
    final sha = c.str('sha');
    final shortSha = sha != null && sha.length >= 7 ? sha.substring(0, 7) : null;
    slides.add(
      _Slide(
        id: 'commit-$i',
        label: 'Recent commit',
        value: shortSha ?? _clip(message, 12),
        sub: _clip(message, 42),
        aside: c.obj('repository')?.str('name'),
        valueSize: shortSha != null ? 28 : 22,
        to: '/github',
      ),
    );
  }
  return slides;
}

List<_Slide> _f1Slides(Json f1) {
  final slides = <_Slide>[];
  final next = f1.obj('next_meeting');
  final days = daysUntil(next?.date('date_start'));
  slides.add(
    _Slide(
      id: 'next',
      label: 'Next race',
      value: days == null
          ? '—'
          : days <= 0
          ? 'Now'
          : '${days}d',
      sub: next?.str('meeting_name') ?? 'Season break',
      to: '/f1',
    ),
  );
  final last = f1.obj('last_meeting');
  if (last != null) {
    slides.add(
      _Slide(
        id: 'last',
        label: 'Last race',
        value: _clip(last.str('circuit_short_name') ?? last.text('meeting_name'), 16),
        sub: last.str('meeting_name'),
        valueSize: 28,
        to: '/f1',
      ),
    );
  }
  for (final (i, d) in f1.list('standings_drivers_top').take(3).indexed) {
    final rawName = d.str('name');
    final name =
        d.str('name_acronym') ?? (rawName != null ? _clip(rawName, 14) : null) ?? '#${d.integer('driver_number')}';
    slides.add(
      _Slide(
        id: 'driver-$i',
        label: i == 0 ? 'Championship' : 'P${d.integer('position') ?? (i + 1)}',
        value: name,
        sub: [
          if (d.number('points') case final pts?) '${_n(pts)} pts',
          ?d.str('team_name'),
        ].whereType<String>().join(' · '),
        valueSize: 32,
        to: '/f1',
      ),
    );
  }
  if (f1.list('standings_teams_top').firstOrNull case final team?) {
    slides.add(
      _Slide(
        id: 'team',
        label: 'Constructors',
        value: _clip(team.text('team_name'), 18),
        sub: team.number('points') != null ? '${_n(team.number('points'))} pts' : null,
        valueSize: 24,
        to: '/f1',
      ),
    );
  }
  return slides;
}

List<_Slide> _sportsSlides(List<Json> fixtures) {
  if (fixtures.isEmpty) {
    return const [
      _Slide(
        id: 'empty',
        label: 'Next fixture',
        value: '—',
        sub: 'Nothing scheduled',
        valueSize: 34,
        to: '/sports/football',
      ),
    ];
  }
  return [
    for (final (i, f) in fixtures.take(6).indexed)
      _Slide(
        id: 'fix-$i',
        label: _sportLabel(f.str('sport_slug')),
        value: f.date('starts_at') != null ? shortDay(f.date('starts_at')!) : '—',
        sub: _clip(f.str('name'), 40),
        aside: f.str('league_name'),
        valueSize: 34,
        to: '/sports/${f.text('sport_slug', 'football')}',
      ),
  ];
}

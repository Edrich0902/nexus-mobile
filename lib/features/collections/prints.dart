import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/widgets/nx_print_card.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/library/library_helpers.dart';

/// Ports of web `routes/collections/prints.ts`: API records → [PrintModel].

DateTime? _day(String? value) {
  if (value == null || value.isEmpty) return null;
  final d = DateTime.tryParse(value.length == 10 ? '${value}T00:00:00' : value);
  return d?.toLocal();
}

/// "12 Sep", or "12 Sep 2024" outside the current year.
String? shortDay(String? value) {
  final d = _day(value);
  if (d == null) return null;
  return DateFormat(d.year == DateTime.now().year ? 'd MMM' : 'd MMM y').format(d);
}

int? _daysBetween(String? from, [String? to]) {
  final a = _day(from);
  final b = to == null ? DateTime.now() : _day(to);
  if (a == null || b == null) return null;
  final days = (b.difference(a).inHours / 24).round() + 1;
  return days < 1 ? 1 : days;
}

String _dated(String prefix, String? value, String fallback) {
  final d = shortDay(value);
  return d == null ? fallback : '$prefix $d';
}

String _joined(List<Object?> parts) => parts.where((p) => p != null && p.toString().isNotEmpty).join(' · ');

String _trimNum(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

Color? _match(List<(String, Color)> table, String text) {
  for (final (re, colour) in table) {
    if (RegExp(re, caseSensitive: false).hasMatch(text)) return colour;
  }
  return null;
}

({List<ProfileAxis>? profile, (String, PrintTone)? status, String? blurb, List<String> notes}) _insight(
  DrinkKind kind,
  Json item, {
  double? abv,
  double? ibu,
}) {
  final analysis = item.obj('ai_analysis');
  final profile = drinkProfile(kind.noun, analysis, abv: abv, ibu: ibu);
  final hasArt = item.obj('media') != null || item.str('image_url') != null;
  (String, PrintTone)? status;
  String? blurb;
  if (profile == null) {
    final s = item.str('analysis_status');
    final notes = analysis?.obj('narrative')?.str('tasting_notes');
    if (s == 'pending') {
      status = ('Reading the label…', PrintTone.busy);
    } else if (s == 'failed') {
      status = ('Couldn’t read this label', PrintTone.error);
    } else if (notes != null) {
      blurb = notes;
    } else if (!hasArt) {
      status = ('Add a label photo for a taste profile', PrintTone.quiet);
    } else {
      status = ('No taste profile yet', PrintTone.quiet);
    }
  }
  return (profile: profile, status: status, blurb: blurb, notes: drinkNotes(analysis));
}

const _wineBg = [
  ('ros[eé]|blush', Color(0xFFD98A86)),
  ('sparkling|champagne|cap classique|cava|prosecco', Color(0xFFCDB777)),
  ('white|blanc|chardonnay', Color(0xFFC9B06A)),
  ('dessert|fortified|port|sherry|noble', Color(0xFFA8641F)),
  ('orange|skin', Color(0xFFC7752E)),
];

PrintModel winePrint(Json w) {
  final tastings = w.integer('tastings_count') ?? 0;
  final i = _insight(DrinkKind.wine, w);
  final vintage = w.integer('vintage');
  return PrintModel(
    key: w.integer('id') ?? 0,
    route: DrinkKind.wine.pathFor(w.integer('id') ?? 0),
    title: w.text('name', 'Wine'),
    by: w.str('producer_name'),
    head: _joined([w.str('wine_type'), w.str('region_name') ?? w.str('country')]),
    headRight: vintage != null ? '$vintage' : 'NV',
    artMode: PrintArt.multiply,
    media: MediaImage.fromJson(w.obj('media')),
    src: w.str('image_url'),
    icon: LucideIcons.wine,
    fallbackBg: _match(_wineBg, w.str('wine_type') ?? '') ?? const Color(0xFF7A1F2E),
    profile: i.profile,
    status: i.status,
    blurb: i.blurb,
    notes: i.notes,
    foot: tastings > 0 ? plural(tastings, 'tasting') : 'Not tasted yet',
    footMono: true,
    rating: w.number('rating'),
  );
}

const _beerBg = [
  ('stout|porter|black|schwarz', Color(0xFF4A2C1C)),
  ('sour|gose|lambic|berliner|fruit', Color(0xFFB8475E)),
  ('ipa|pale ale|apa|amber|red', Color(0xFFB8661B)),
  ('wheat|weiss|wit|hefe', Color(0xFFE0B13A)),
];

PrintModel beerPrint(Json b) {
  final style = b.obj('style');
  final brewery = b.obj('brewery');
  final abv = b.number('abv');
  final i = _insight(DrinkKind.beer, b, ibu: b.number('ibu'));
  return PrintModel(
    key: b.integer('id') ?? 0,
    route: DrinkKind.beer.pathFor(b.integer('id') ?? 0),
    title: b.text('name', 'Beer'),
    by: brewery?.str('name'),
    head: _joined([style?.str('name'), brewery?.str('city') ?? brewery?.str('country')]),
    headRight: abv != null ? '${abv.toStringAsFixed(1)}% ABV' : null,
    artMode: PrintArt.cutout,
    media: MediaImage.fromJson(b.obj('media')),
    src: b.str('image_url'),
    icon: LucideIcons.beer,
    fallbackBg: _match(_beerBg, '${style?.str('name') ?? ''} ${style?.str('family') ?? ''}') ?? const Color(0xFFD39A17),
    profile: i.profile,
    status: i.status,
    blurb: i.blurb,
    notes: i.notes,
    foot: _joined([if (shortDay(b.str('created_at')) case final d?) 'Logged $d', b.str('format')]),
    footMono: true,
    rating: b.number('rating'),
  );
}

const _spiritBg = [
  ('gin', Color(0xFF4F7F7A)),
  ('rum', Color(0xFF7A3B1C)),
  ('brandy|cognac|armagnac', Color(0xFF8A4520)),
  ('tequila|mezcal|agave', Color(0xFF8D9A4E)),
  ('vodka', Color(0xFF6F7F99)),
  ('liqueur|amaro|cream', Color(0xFF8A3A5C)),
  ('whisk|bourbon|scotch|rye', Color(0xFFA8641F)),
];

PrintModel spiritPrint(Json s) {
  final abv = s.number('abv');
  final i = _insight(DrinkKind.spirit, s, abv: abv);
  final right = _joined([s.str('age_statement'), if (abv != null) '${_trimNum(abv)}%']);
  return PrintModel(
    key: s.integer('id') ?? 0,
    route: DrinkKind.spirit.pathFor(s.integer('id') ?? 0),
    title: s.text('name', 'Spirit'),
    by: s.str('producer'),
    head: _joined([s.str('category'), s.str('region') ?? s.str('country')]),
    headRight: right.isEmpty ? null : right,
    artMode: PrintArt.multiply,
    media: MediaImage.fromJson(s.obj('media')),
    src: s.str('image_url'),
    icon: LucideIcons.glassWater,
    fallbackBg: _match(_spiritBg, s.str('category') ?? '') ?? const Color(0xFFC8743A),
    profile: i.profile,
    status: i.status,
    blurb: i.blurb,
    notes: i.notes,
    foot: _dated('Added', s.str('created_at'), 'On the shelf'),
    footMono: true,
    rating: s.number('rating'),
  );
}

PrintModel drinkPrint(DrinkKind kind, Json item) => switch (kind) {
  DrinkKind.wine => winePrint(item),
  DrinkKind.beer => beerPrint(item),
  DrinkKind.spirit => spiritPrint(item),
};

/* ── Books ──────────────────────────────────────────────── */

/// First paragraph of an Open Library description, without markdown links.
String? firstParagraph(String? text) {
  if (text == null) return null;
  final para = text
      .split(RegExp(r'\n\s*\n|-{3,}'))
      .first
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'\[\d+\]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return para.isEmpty ? null : para;
}

List<String> bookAuthorList(Json b) {
  final catalog = b.obj('catalog')?.strings('authors') ?? const [];
  final list = catalog.isNotEmpty ? catalog : (b.str('authors') ?? '').split(RegExp(r'\s*(?:,|&|\band\b)\s*'));
  return {for (final a in list) a.trim()}.where((a) => a.isNotEmpty).toList();
}

PrintModel bookPrint(Json b) {
  final pages = b.obj('catalog')?.integer('page_count');
  final status = b.str('status');
  final started = b.str('started_at');
  final finished = b.str('finished_at');
  (int, String, String?) progress;
  String foot;
  if (status == 'reading') {
    final days = _daysBetween(started);
    progress = (2, days != null ? 'Reading · day $days' : 'Reading', null);
    foot = _dated('Started', started, 'Reading now');
  } else if (status == 'read') {
    final days = started != null && finished != null ? _daysBetween(started, finished) : null;
    progress = (3, days != null ? 'Read in ${plural(days, 'day')}' : 'Read', null);
    foot = _dated('Finished', finished, 'Finished');
  } else {
    progress = (1, 'Not started', null);
    foot = _dated('Added', b.str('created_at'), 'On the wishlist');
  }
  final year = b.obj('catalog')?.integer('publish_year');
  return PrintModel(
    key: b.integer('id') ?? 0,
    route: '/library/books/${b.integer('id')}',
    title: b.text('title', 'Untitled'),
    by: bookAuthors(b),
    head: bookStatusLabel(status),
    headRight: year?.toString(),
    artMode: PrintArt.cover,
    media: MediaImage.fromJson(b.obj('media')),
    src: b.str('image_url'),
    icon: LucideIcons.bookOpen,
    fallbackBg: const Color(0xFF3E4A6E),
    notes: bookAuthorList(b),
    tags: const [],
    progress: (progress.$1, progress.$2, pages != null ? '$pages pages' : null),
    blurb: firstParagraph(b.obj('catalog')?.str('description')),
    foot: foot,
    rating: b.number('rating'),
  );
}

/* ── Recipes ────────────────────────────────────────────── */

PrintModel recipePrint(Json r, {String? pair}) {
  final meal = r.obj('meal');
  final traits = [
    meal?.str('category'),
    meal?.str('area'),
    ...?meal?.strings('tags'),
  ].map((t) => t?.trim()).whereType<String>().where((t) => t.isNotEmpty);
  final notes = {...traits}.toList();
  final extra = notes.where((t) => t != meal?.str('category') && t != meal?.str('area')).toList();
  final src = r.str('image_url') ?? meal?.str('thumb_url');
  final cooked = r.integer('cooked_count') ?? 0;
  final ingredients = meal?.list('ingredients').length ?? 0;
  final favourite = r.flag('is_favourite');
  final firstNote = r.str('notes')?.split('\n').first;
  return PrintModel(
    key: r.integer('id') ?? 0,
    route: '/kitchen/recipes/${r.integer('id')}',
    title: meal?.str('name') ?? 'Recipe',
    by: firstNote == null || firstNote.isEmpty ? null : firstNote,
    head: _joined([meal?.str('area'), meal?.str('category')]),
    artMode: PrintArt.photo,
    media: MediaImage.fromJson(r.obj('media')),
    src: src,
    icon: LucideIcons.chefHat,
    fallbackBg: const Color(0xFF4F6B47),
    notes: notes,
    tags: extra.isNotEmpty ? extra : notes,
    facts: [
      ('Ingredients', ingredients > 0 ? '$ingredients' : '—'),
      ('Cooked', '$cooked×'),
      ('Last cooked', shortDay(r.str('last_cooked_on')) ?? 'Not yet'),
    ],
    cooked: (cooked, cooked > 6 ? '+${cooked - 6} more' : null),
    pair: pair,
    foot: favourite ? 'A favourite' : _dated('Saved', r.str('created_at'), 'Saved'),
    rating: r.number('rating'),
    favourite: favourite,
  );
}

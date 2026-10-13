import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/tokens.g.dart';

/// The three bottle collections share one index/detail implementation; this
/// carries everything that differs between them (API paths, copy, routes).
enum DrinkKind {
  wine(
    noun: 'wine',
    label: 'Wine',
    section: SectionKey.cellar,
    icon: LucideIcons.wine,
    apiBase: '/cellar/wines',
    route: '/cellar',
    detailRoute: '/cellar/wines',
    uploadCollection: 'cellar',
    attachType: 'cellar_wine',
  ),
  beer(
    noun: 'beer',
    label: 'Beer',
    section: SectionKey.beer,
    icon: LucideIcons.beer,
    apiBase: '/beer/beers',
    route: '/beer',
    detailRoute: '/beer/beers',
    uploadCollection: 'beer',
    attachType: 'beer_beer',
  ),
  spirit(
    noun: 'spirit',
    label: 'Spirits',
    section: SectionKey.spirits,
    icon: LucideIcons.glassWater,
    apiBase: '/spirits/spirits',
    route: '/spirits',
    detailRoute: '/spirits',
    uploadCollection: 'spirits',
    attachType: 'spirit_spirit',
  );

  new({
    required this.noun,
    required this.label,
    required this.section,
    required this.icon,
    required this.apiBase,
    required this.route,
    required this.detailRoute,
    required this.uploadCollection,
    required this.attachType,
  });

  final String noun;
  final String label;
  final SectionKey section;
  final IconData icon;
  final String apiBase;
  final String route;
  final String detailRoute;
  final String uploadCollection;
  final String attachType;

  String pathFor(int id) => '$detailRoute/$id';

  /// Index stage copy (web CellarView / BeerView / SpiritsView).
  ({String eyebrow, String title, String accent, String lede, String add, String search}) get copy => switch (this) {
    wine => (
      eyebrow: 'Cellar',
      title: 'Wine',
      accent: 'journal',
      lede: 'Every bottle you open — label photos, tastings and AI notes on structure and pairings.',
      add: 'Add wine',
      search: 'Search wines, producers, regions…',
    ),
    beer => (
      eyebrow: 'Taproom',
      title: 'Beer',
      accent: 'log',
      lede: 'Every can, bottle and pour — linked to its brewery, with AI notes on style and bitterness.',
      add: 'Log a beer',
      search: 'Search beers and breweries…',
    ),
    spirit => (
      eyebrow: 'Bar cart',
      title: 'Spirits',
      accent: 'shelf',
      lede: 'Whisky, gin, rum and the rest — bottle photos, age statements and AI notes on nose and finish.',
      add: 'Add a bottle',
      search: 'Search spirits and distilleries…',
    ),
  };

  ({String title, String body, String action, String noMatch}) get empty => switch (this) {
    wine => (
      title: 'Your cellar is empty',
      body: 'Add the bottle you are drinking tonight. A label photo lets AI write the tasting notes for you.',
      action: 'Add your first wine',
      noMatch: 'Try a producer, a region or part of the name.',
    ),
    beer => (
      title: 'No beers logged yet',
      body: 'Log what you are drinking and link it to a brewery from Open Brewery DB, or add your own.',
      action: 'Log your first beer',
      noMatch: 'Try a brewery or a style.',
    ),
    spirit => (
      title: 'The shelf is bare',
      body: 'Add a bottle and a label photo; AI will fill in the nose, palate and finish.',
      action: 'Add your first bottle',
      noMatch: 'Try a distillery or a category.',
    ),
  };

  String get countLabel => this == beer ? 'Beers logged' : 'Bottles';
}

/// Until a label palette arrives, wine pages tint by style rather than
/// always red (web CellarWineView STYLE_AMBIENTS).
Ambient? wineStyleAmbient(String? type) {
  if (type == null) return null;
  const table = <(String, Ambient)>[
    (
      'sparkl|champ|cap class|cava|prosecco',
      Ambient(amb: Color(0xFF17150C), amb2: Color(0xFF262213), acc: Color(0xFFECD58A), ink: Color(0xFFFBF7E6)),
    ),
    (
      'ros[eé]|blush',
      Ambient(amb: Color(0xFF1F0D12), amb2: Color(0xFF33161E), acc: Color(0xFFF2A0B0), ink: Color(0xFFFDEEF1)),
    ),
    (
      'white|blanc|chard|chenin|riesling|sauv',
      Ambient(amb: Color(0xFF18170C), amb2: Color(0xFF28261A), acc: Color(0xFFE3CF7F), ink: Color(0xFFFBF7E8)),
    ),
    (
      'dessert|fortified|port|sherry|noble',
      Ambient(amb: Color(0xFF1D0F07), amb2: Color(0xFF2F1A0C), acc: Color(0xFFEAA35A), ink: Color(0xFFFCF0E3)),
    ),
  ];
  for (final (re, ambient) in table) {
    if (RegExp(re, caseSensitive: false).hasMatch(type)) return ambient;
  }
  return null;
}

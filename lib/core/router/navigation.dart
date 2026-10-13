import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/design/tokens.g.dart';

/// Mirrors web `design/navigation.ts` so both clients share destinations,
/// section colours and path → section mapping.
class Destination {
  const new(this.key, this.label, this.icon, this.to, this.section, {this.keywords = const []});

  final String key;
  final String label;
  final IconData icon;
  final String to;
  final SectionKey section;
  final List<String> keywords;
}

abstract final class Nav {
  static const home = Destination('home', 'Home', LucideIcons.house, '/home', SectionKey.home);
  static const listening = Destination(
    'listening',
    'Listening',
    LucideIcons.audioLines,
    '/spotify',
    SectionKey.listening,
    keywords: ['spotify', 'music'],
  );
  static const code = Destination(
    'code',
    'Code',
    LucideIcons.codeXml,
    '/github',
    SectionKey.code,
    keywords: ['github', 'pull requests'],
  );
  static const cellar = Destination(
    'cellar',
    'Wine',
    LucideIcons.wine,
    '/cellar',
    SectionKey.cellar,
    keywords: ['cellar', 'bottles'],
  );
  static const beer = Destination('beer', 'Beer', LucideIcons.beer, '/beer', SectionKey.beer);
  static const spirits = Destination(
    'spirits',
    'Spirits',
    LucideIcons.glassWater,
    '/spirits',
    SectionKey.spirits,
    keywords: ['whisky', 'gin', 'rum'],
  );
  static const kitchen = Destination(
    'kitchen',
    'Recipes',
    LucideIcons.chefHat,
    '/kitchen',
    SectionKey.kitchen,
    keywords: ['kitchen', 'cook'],
  );
  static const foodDrink = Destination(
    'food-drink',
    'Food & Drink',
    LucideIcons.utensilsCrossed,
    '/food-drink',
    SectionKey.foodDrink,
    keywords: ['pairings'],
  );
  static const library = Destination(
    'library',
    'Library',
    LucideIcons.bookOpen,
    '/library',
    SectionKey.library,
    keywords: ['books', 'reading'],
  );
  static const f1 = Destination(
    'f1',
    'Formula 1',
    LucideIcons.flag,
    '/f1',
    SectionKey.f1,
    keywords: ['race', 'grand prix'],
  );
  static const sports = Destination(
    'sports',
    'Sports',
    LucideIcons.trophy,
    '/sports/football',
    SectionKey.sports,
    keywords: ['football', 'rugby', 'tennis'],
  );
  static const media = Destination(
    'media',
    'Media vault',
    LucideIcons.images,
    '/media',
    SectionKey.media,
    keywords: ['photos', 'images'],
  );
  static const admin = Destination(
    'admin',
    'Admin',
    LucideIcons.gauge,
    '/admin',
    SectionKey.admin,
    keywords: ['queue', 'jobs', 'ops'],
  );
  static const profile = Destination(
    'profile',
    'Profile',
    LucideIcons.circleUser,
    '/profile',
    SectionKey.profile,
    keywords: ['account'],
  );

  /// Phone tab bar (plus "More" as the fifth tab).
  static const List<Destination> phoneTabs = [home, listening, cellar, f1];

  static const List<Destination> primary = [
    home,
    listening,
    code,
    cellar,
    beer,
    spirits,
    kitchen,
    foodDrink,
    library,
    f1,
    sports,
  ];

  static const List<Destination> secondary = [media, admin, profile];

  static const sub = [
    Destination('spotify-search', 'Search Spotify', LucideIcons.search, '/spotify/search', SectionKey.listening),
    Destination(
      'spotify-library',
      'Your Spotify library',
      LucideIcons.music,
      '/spotify/library',
      SectionKey.listening,
      keywords: ['playlists'],
    ),
    Destination(
      'spotify-stats',
      'Listening stats',
      LucideIcons.audioLines,
      '/spotify/stats',
      SectionKey.listening,
      keywords: ['top artists'],
    ),
    Destination(
      'github-pulls',
      'Pull requests',
      LucideIcons.gitPullRequest,
      '/github/pulls',
      SectionKey.code,
      keywords: ['prs', 'reviews'],
    ),
    Destination(
      'github-search',
      'Search code',
      LucideIcons.search,
      '/github/search',
      SectionKey.code,
      keywords: ['repositories'],
    ),
    Destination(
      'github-stats',
      'Code stats',
      LucideIcons.chartColumn,
      '/github/stats',
      SectionKey.code,
      keywords: ['contributions'],
    ),
    Destination('kitchen-discover', 'Discover recipes', LucideIcons.chefHat, '/kitchen/discover', SectionKey.kitchen),
    Destination(
      'pairings',
      'Food and drink pairings',
      LucideIcons.utensilsCrossed,
      '/food-drink/pairings',
      SectionKey.foodDrink,
    ),
    Destination(
      'sessions',
      'Signed-in devices',
      LucideIcons.smartphone,
      '/profile/sessions',
      SectionKey.profile,
      keywords: ['sessions', 'security'],
    ),
    Destination('sport-rugby', 'Rugby', LucideIcons.trophy, '/sports/rugby', SectionKey.sports),
    Destination('sport-tennis', 'Tennis', LucideIcons.trophy, '/sports/tennis', SectionKey.sports),
    Destination('sport-golf', 'Golf', LucideIcons.trophy, '/sports/golf', SectionKey.sports),
    Destination('sport-darts', 'Darts', LucideIcons.trophy, '/sports/darts', SectionKey.sports),
    Destination('sport-field-hockey', 'Field hockey', LucideIcons.trophy, '/sports/field-hockey', SectionKey.sports),
  ];

  static const List<Destination> all = [...primary, ...secondary, ...sub];

  static const _prefixSections = <(String, SectionKey)>[
    ('/spotify', SectionKey.listening),
    ('/github', SectionKey.code),
    ('/cellar', SectionKey.cellar),
    ('/beer', SectionKey.beer),
    ('/spirits', SectionKey.spirits),
    ('/kitchen', SectionKey.kitchen),
    ('/food-drink', SectionKey.foodDrink),
    ('/library', SectionKey.library),
    ('/f1', SectionKey.f1),
    ('/sports', SectionKey.sports),
    ('/media', SectionKey.media),
    ('/admin', SectionKey.admin),
    ('/profile', SectionKey.profile),
    ('/login', SectionKey.auth),
  ];

  static SectionKey sectionFor(String path) {
    for (final (prefix, key) in _prefixSections) {
      if (path == prefix || path.startsWith('$prefix/')) return key;
    }
    return SectionKey.home;
  }

  static bool isActive(Destination d, String path) {
    if (d.key == 'sports') return path.startsWith('/sports');
    return path == d.to || path.startsWith('${d.to}/');
  }
}

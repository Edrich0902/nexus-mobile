import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/features/capture/capture_screen.dart';
import 'package:nexus_mobile/features/collections/brewery_screen.dart';
import 'package:nexus_mobile/features/collections/collection_index.dart';
import 'package:nexus_mobile/features/collections/drink_detail.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/food_drink/food_drink_screen.dart';
import 'package:nexus_mobile/features/food_drink/pairings_screen.dart';
import 'package:nexus_mobile/features/home/home_screen.dart';
import 'package:nexus_mobile/features/kitchen/discover_screen.dart';
import 'package:nexus_mobile/features/kitchen/kitchen_screen.dart';
import 'package:nexus_mobile/features/kitchen/recipe_screen.dart';
import 'package:nexus_mobile/features/library/book_screen.dart';
import 'package:nexus_mobile/features/library/library_screen.dart';
import 'package:nexus_mobile/features/listening/listening_screen.dart';
import 'package:nexus_mobile/features/listening/spotify_browse.dart';
import 'package:nexus_mobile/features/listening/spotify_library_screen.dart';
import 'package:nexus_mobile/features/listening/spotify_playlist.dart';
import 'package:nexus_mobile/features/listening/spotify_search_screen.dart';
import 'package:nexus_mobile/features/listening/spotify_stats_screen.dart';
import 'package:nexus_mobile/features/profile/profile_screen.dart';
import 'package:nexus_mobile/features/profile/sessions_screen.dart';

int _id(GoRouterState s, String name) => int.tryParse(s.pathParameters[name] ?? '') ?? 0;

/// Routes rendered inside the shell (top bar + phone bar). Paths mirror
/// nexus-web so links from the API (activity, search, push) open as-is.
final appRoutes = <RouteBase>[
  GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
  GoRoute(
    path: '/spotify',
    builder: (_, _) => const ListeningScreen(),
    routes: [
      GoRoute(
        path: 'search',
        builder: (_, s) => SpotifySearchScreen(initialQuery: s.uri.queryParameters['q']),
      ),
      GoRoute(path: 'library', builder: (_, _) => const SpotifyLibraryScreen()),
      GoRoute(path: 'stats', builder: (_, _) => const SpotifyStatsScreen()),
      GoRoute(
        path: 'artists/:artistId',
        builder: (_, s) => ArtistScreen(id: s.pathParameters['artistId'] ?? ''),
      ),
      GoRoute(
        path: 'albums/:albumId',
        builder: (_, s) => AlbumScreen(id: s.pathParameters['albumId'] ?? ''),
      ),
      GoRoute(
        path: 'playlists/:playlistId',
        builder: (_, s) => PlaylistScreen(id: s.pathParameters['playlistId'] ?? ''),
      ),
    ],
  ),
  GoRoute(
    path: '/cellar',
    builder: (_, _) => const DrinkIndexScreen(kind: DrinkKind.wine),
    routes: [
      GoRoute(
        path: 'wines/:wineId',
        builder: (_, s) => DrinkDetailScreen(kind: DrinkKind.wine, id: _id(s, 'wineId')),
      ),
    ],
  ),
  GoRoute(
    path: '/beer',
    builder: (_, _) => const DrinkIndexScreen(kind: DrinkKind.beer),
    routes: [
      GoRoute(
        path: 'beers/:beerId',
        builder: (_, s) => DrinkDetailScreen(kind: DrinkKind.beer, id: _id(s, 'beerId')),
      ),
      GoRoute(
        path: 'breweries/:breweryId',
        builder: (_, s) => BreweryScreen(id: _id(s, 'breweryId')),
      ),
    ],
  ),
  GoRoute(
    path: '/spirits',
    builder: (_, _) => const DrinkIndexScreen(kind: DrinkKind.spirit),
    routes: [
      GoRoute(
        path: ':spiritId',
        builder: (_, s) => DrinkDetailScreen(kind: DrinkKind.spirit, id: _id(s, 'spiritId')),
      ),
    ],
  ),
  GoRoute(
    path: '/library',
    builder: (_, _) => const LibraryScreen(),
    routes: [
      GoRoute(
        path: 'books/:bookId',
        builder: (_, s) => BookScreen(id: _id(s, 'bookId')),
      ),
    ],
  ),
  GoRoute(
    path: '/kitchen',
    builder: (_, _) => const KitchenScreen(),
    routes: [
      GoRoute(
        path: 'discover',
        builder: (_, _) => const DiscoverScreen(),
        routes: [
          GoRoute(
            path: ':mealdbId',
            builder: (_, s) => MealPreviewScreen(mealdbId: s.pathParameters['mealdbId'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: 'recipes/:recipeId',
        builder: (_, s) => SavedRecipeScreen(id: _id(s, 'recipeId')),
      ),
    ],
  ),
  GoRoute(
    path: '/food-drink',
    builder: (_, _) => const FoodDrinkScreen(),
    routes: [GoRoute(path: 'pairings', builder: (_, _) => const PairingsScreen())],
  ),
  GoRoute(
    path: '/profile',
    builder: (_, _) => const ProfileScreen(),
    routes: [GoRoute(path: 'sessions', builder: (_, _) => const SessionsScreen())],
  ),
];

/// Full-screen routes above the shell (camera, scanner, replay).
final rootRoutes = <RouteBase>[
  GoRoute(
    path: '/capture',
    builder: (_, s) => CaptureScreen(
      kind: s.uri.queryParameters['kind'],
      barcode: s.uri.queryParameters['mode'] == 'barcode',
    ),
  ),
];

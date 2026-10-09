import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/core/router/transitions.dart';
import 'package:nexus_mobile/features/admin/admin_screen.dart';
import 'package:nexus_mobile/features/capture/capture_screen.dart';
import 'package:nexus_mobile/features/code/github_pull_create_screen.dart';
import 'package:nexus_mobile/features/code/github_pull_screen.dart';
import 'package:nexus_mobile/features/code/github_pulls_screen.dart';
import 'package:nexus_mobile/features/code/github_repo_screen.dart';
import 'package:nexus_mobile/features/code/github_screen.dart';
import 'package:nexus_mobile/features/code/github_search_screen.dart';
import 'package:nexus_mobile/features/code/github_stats_screen.dart';
import 'package:nexus_mobile/features/collections/brewery_screen.dart';
import 'package:nexus_mobile/features/collections/collection_index.dart';
import 'package:nexus_mobile/features/collections/drink_detail.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/f1/f1_meeting_screen.dart';
import 'package:nexus_mobile/features/f1/f1_replay_screen.dart';
import 'package:nexus_mobile/features/f1/f1_screen.dart';
import 'package:nexus_mobile/features/f1/f1_session_screen.dart';
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
import 'package:nexus_mobile/features/media/media_vault_screen.dart';
import 'package:nexus_mobile/features/profile/profile_screen.dart';
import 'package:nexus_mobile/features/profile/sessions_screen.dart';
import 'package:nexus_mobile/features/sports/sport_screen.dart';

int _id(GoRouterState s, String name) => int.tryParse(s.pathParameters[name] ?? '') ?? 0;

/// Routes rendered inside the shell (top bar + phone bar). Paths mirror
/// nexus-web so links from the API (activity, search, push) open as-is.
final appRoutes = <RouteBase>[
  fadeRoute('/home', (_) => const HomeScreen()),
  fadeRoute(
    '/spotify',
    (_) => const ListeningScreen(),
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
  fadeRoute(
    '/cellar',
    (_) => const DrinkIndexScreen(kind: DrinkKind.wine),
    routes: [
      GoRoute(
        path: 'wines/:wineId',
        builder: (_, s) => DrinkDetailScreen(kind: DrinkKind.wine, id: _id(s, 'wineId')),
      ),
    ],
  ),
  fadeRoute(
    '/beer',
    (_) => const DrinkIndexScreen(kind: DrinkKind.beer),
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
  fadeRoute(
    '/spirits',
    (_) => const DrinkIndexScreen(kind: DrinkKind.spirit),
    routes: [
      GoRoute(
        path: ':spiritId',
        builder: (_, s) => DrinkDetailScreen(kind: DrinkKind.spirit, id: _id(s, 'spiritId')),
      ),
    ],
  ),
  fadeRoute(
    '/library',
    (_) => const LibraryScreen(),
    routes: [
      GoRoute(
        path: 'books/:bookId',
        builder: (_, s) => BookScreen(id: _id(s, 'bookId')),
      ),
    ],
  ),
  fadeRoute(
    '/kitchen',
    (_) => const KitchenScreen(),
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
  fadeRoute(
    '/food-drink',
    (_) => const FoodDrinkScreen(),
    routes: [GoRoute(path: 'pairings', builder: (_, _) => const PairingsScreen())],
  ),
  fadeRoute(
    '/f1',
    (_) => const F1Screen(),
    routes: [
      GoRoute(
        path: 'meetings/:meetingKey',
        builder: (_, s) => F1MeetingScreen(meetingKey: _id(s, 'meetingKey')),
      ),
      GoRoute(
        path: 'sessions/:sessionKey',
        builder: (_, s) => F1SessionScreen(sessionKey: _id(s, 'sessionKey')),
        routes: [
          GoRoute(
            path: 'replay',
            builder: (_, s) => F1ReplayScreen(sessionKey: _id(s, 'sessionKey')),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: '/sports',
    redirect: (_, s) => s.uri.path == '/sports' || s.uri.path == '/sports/' ? '/sports/football' : null,
    routes: [
      fadeRoute(':sport', (s) => SportScreen(sport: s.pathParameters['sport'] ?? 'football')),
    ],
  ),
  fadeRoute(
    '/github',
    (_) => const GithubScreen(),
    routes: [
      GoRoute(path: 'pulls', builder: (_, _) => const GithubPullsScreen()),
      GoRoute(path: 'search', builder: (_, _) => const GithubSearchScreen()),
      GoRoute(path: 'stats', builder: (_, _) => const GithubStatsScreen()),
      GoRoute(
        path: ':owner/:repo',
        builder: (_, s) =>
            GithubRepoScreen(owner: s.pathParameters['owner'] ?? '', repo: s.pathParameters['repo'] ?? ''),
        routes: [
          GoRoute(
            path: 'pulls/new',
            builder: (_, s) => GithubPullCreateScreen(
              owner: s.pathParameters['owner'] ?? '',
              repo: s.pathParameters['repo'] ?? '',
              head: s.uri.queryParameters['head'],
            ),
          ),
          GoRoute(
            path: 'pulls/:number',
            builder: (_, s) => GithubPullScreen(
              owner: s.pathParameters['owner'] ?? '',
              repo: s.pathParameters['repo'] ?? '',
              number: _id(s, 'number'),
            ),
          ),
        ],
      ),
    ],
  ),
  fadeRoute('/media', (_) => const MediaVaultScreen()),
  fadeRoute('/admin', (_) => const AdminScreen()),
  fadeRoute(
    '/profile',
    (_) => const ProfileScreen(),
    routes: [GoRoute(path: 'sessions', builder: (_, _) => const SessionsScreen())],
  ),
];

/// Full-screen routes above the shell (camera, scanner, replay).
final rootRoutes = <RouteBase>[
  GoRoute(
    path: '/capture',
    pageBuilder: (_, s) => MaterialPage(
      key: s.pageKey,
      fullscreenDialog: true,
      child: CaptureScreen(
        kind: s.uri.queryParameters['kind'],
        barcode: s.uri.queryParameters['mode'] == 'barcode',
      ),
    ),
  ),
];

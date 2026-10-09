import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/meta/app_meta.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/features/home/hub_api.dart';
import 'package:nexus_mobile/features/profile/sessions_screen.dart';
import 'package:nexus_mobile/shell/search_sheet.dart';
import 'package:nexus_mobile/shell/top_bar.dart';

void main() {
  test('compareVersions orders semver-ish strings', () {
    expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
    expect(compareVersions('2.0', '2.0.0'), 0);
    expect(compareVersions('0.3.1', '0.3.0'), greaterThan(0));
  });

  test('JsonRead is null-safe and lenient', () {
    final j = <String, dynamic>{
      'n': '12',
      'f': 1,
      'o': {
        'a': [
          {'b': 'x'},
        ],
      },
      'e': '',
    };
    expect(j.integer('n'), 12);
    expect(j.flag('f'), isTrue);
    expect(j.str('e'), isNull);
    expect(j.at('o.a.0.b'), 'x');
    expect(j.list('missing'), isEmpty);
  });

  test('relativeTime', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(relativeTime(now.subtract(const Duration(seconds: 5)), now: now), 'just now');
    expect(relativeTime(now.subtract(const Duration(minutes: 3)), now: now), '3 min ago');
    expect(relativeTime(now.subtract(const Duration(days: 1)), now: now), 'yesterday');
    expect(relativeTime(now.add(const Duration(hours: 2)), now: now), 'in 2 h');
  });

  test('section mapping mirrors web navigation', () {
    expect(Nav.sectionFor('/cellar/wines/4'), SectionKey.cellar);
    expect(Nav.sectionFor('/food-drink/pairings'), SectionKey.foodDrink);
    expect(Nav.sectionFor('/nowhere'), SectionKey.home);
    expect(isRootPath('/cellar'), isTrue);
    expect(isRootPath('/sports/rugby'), isTrue);
    expect(isRootPath('/cellar/wines/4'), isFalse);
    expect(sectionDestination('/github/a/b/pulls/3').label, 'Code');
  });

  test('command palette scoring', () {
    expect(matchScore('Formula 1', 'form'), 3);
    expect(matchScore('Food & Drink', 'drink'), 2);
    expect(matchScore('Library', 'bra'), 1);
    expect(matchScore('Library', 'zzz'), 0);
  });

  test('search result paths match web routes', () {
    expect(searchItemPath({'type': 'cellar_wine', 'id': 3}), '/cellar/wines/3');
    expect(searchItemPath({'type': 'github_repo', 'id': 1, 'owner': 'o', 'repo': 'r'}), '/github/o/r');
    expect(searchItemPath({'type': 'unknown', 'id': 1}), isNull);
  });

  test('describeAgent', () {
    expect(describeAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120 Safari/537'), 'Chrome on macOS');
    expect(describeAgent('Dart/3.9 (dart:io)'), 'Nexus app');
    expect(describeAgent(null), isNull);
  });
}

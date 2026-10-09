import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/core/router/transitions.dart';
import 'package:nexus_mobile/design/theme.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// How much of [text] reaches the screen: its own fades, times whatever
/// share of it a covering backdrop still lets through.
double _visible(WidgetTester tester, String text, {double covered = 0}) {
  final f = find.text(text);
  if (f.evaluate().isEmpty) return 0;
  var o = 1 - covered;
  for (final e in find.ancestor(of: f, matching: find.byType(FadeTransition)).evaluate()) {
    o *= (e.widget as FadeTransition).opacity.value;
  }
  for (final e in find.ancestor(of: f, matching: find.byType(Opacity)).evaluate()) {
    o *= (e.widget as Opacity).opacity;
  }
  return o;
}

double _backdrop(WidgetTester tester) {
  final f = find.byKey(fadeThroughBackdropKey);
  // Both routes carry one; the incoming (top) one is last in paint order.
  return f.evaluate().isEmpty ? 0 : tester.widgetList<FadeTransition>(f).last.opacity.value;
}

Future<GoRouter> _app(WidgetTester tester, List<RouteBase> routes, {String initial = '/a'}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [ShellRoute(builder: (_, _, child) => child, routes: routes)],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: buildNexusTheme(SectionKey.home.ambient), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('switching tabs fades through: old and new content are never on screen together', (tester) async {
    final router = await _app(tester, [
      fadeRoute('/a', (_) => const Text('Old tab')),
      fadeRoute('/b', (_) => const Text('New tab')),
    ]);

    router.go('/b');
    await tester.pump();
    var sawNew = false;
    for (var t = 0; t <= 400; t += 16) {
      final old = _visible(tester, 'Old tab', covered: _backdrop(tester));
      final next = _visible(tester, 'New tab');
      expect(old < .02 || next < .02, isTrue, reason: 'at ${t}ms old=$old new=$next overlap');
      sawNew |= next > .02;
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(sawNew, isTrue);
    expect(find.text('Old tab'), findsNothing);
    expect(_visible(tester, 'New tab'), 1);
  });

  testWidgets('pushed detail pages are opaque, so the page underneath never shows through', (tester) async {
    final router = await _app(tester, [
      fadeRoute(
        '/a',
        (_) => const Text('List'),
        routes: [GoRoute(path: 'detail', builder: (_, _) => const Text('Detail'))],
      ),
    ]);

    router.go('/a/detail');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final amb = Theme.of(tester.element(find.text('Detail'))).scaffoldBackgroundColor;
    expect(amb.a, 1);
    expect(
      find.ancestor(
        of: find.text('Detail'),
        matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == amb),
      ),
      findsWidgets,
    );
  });

  testWidgets('NxSwitcher lets the old state leave before the new one arrives', (tester) async {
    Widget app(Widget child) => MaterialApp(
      theme: buildNexusTheme(SectionKey.home.ambient),
      home: Scaffold(body: NxSwitcher(child: child)),
    );
    await tester.pumpWidget(app(const Text('Loading', key: ValueKey('loading'))));
    await tester.pumpWidget(app(const Text('Content', key: ValueKey('data'))));

    var sawContent = false;
    for (var t = 0; t <= 700; t += 16) {
      final old = _visible(tester, 'Loading');
      final next = _visible(tester, 'Content');
      expect(old < .05 || next < .05, isTrue, reason: 'at ${t}ms loading=$old content=$next overlap');
      sawContent |= next > .05;
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(sawContent, isTrue);
    expect(find.text('Loading'), findsNothing);
  });
}

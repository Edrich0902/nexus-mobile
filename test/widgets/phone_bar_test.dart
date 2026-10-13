import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/theme.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/shell/phone_bar.dart';

import '../support/fakes.dart';

class _PausedTrack extends PlayerController {
  @override
  PlayerState build() => PlayerState(
    playback: {
      'is_playing': false,
      'progress_ms': 1000,
      'item': {'name': 'Pelota', 'duration_ms': 200000},
    },
    syncedAt: DateTime.now(),
  );
}

void main() {
  testWidgets('the dock collapses to the active tab and docks the player beside it', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final collapsed = ValueNotifier(false);
    addTearDown(collapsed.dispose);
    var expands = 0;

    await tester.pumpWidget(
      nexusTestApp(
        PhoneBar(location: '/cellar', collapsed: collapsed, onExpand: () => expands++),
        overrides: [playerProvider.overrideWith(_PausedTrack.new)],
      ),
    );
    await tester.pumpAndSettle();

    Rect mini() => tester.getRect(find.ancestor(of: find.text('Pelota'), matching: find.byType(NxGlass)).first);

    expect(find.text('Wine'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(mini().left, PhoneBar.side);
    expect(find.byTooltip('Next track'), findsOneWidget);

    collapsed.value = true;
    await tester.pumpAndSettle();

    expect(mini().left, PhoneBar.side + PhoneBar.dockHeight + PhoneBar.gap);
    expect(mini().right, 390 - PhoneBar.side - PhoneBar.dockHeight - PhoneBar.gap);
    expect(find.byTooltip('Next track'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Show tabs'));
    expect(expands, 1);
  });

  testWidgets('dragging the lens onto another tab opens it', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final collapsed = ValueNotifier(false);
    addTearDown(collapsed.dispose);
    final router = GoRouter(
      initialLocation: Nav.home.to,
      routes: [
        ShellRoute(
          builder: (_, state, child) => Scaffold(
            body: Stack(
              children: [
                child,
                Positioned.fill(
                  child: PhoneBar(location: state.uri.path, collapsed: collapsed, onExpand: () {}),
                ),
              ],
            ),
          ),
          routes: [for (final d in Nav.phoneTabs) GoRoute(path: d.to, builder: (_, _) => const SizedBox())],
        ),
      ],
    );
    addTearDown(router.dispose);

    // Load the bundled fonts first: tests never relayout text when a font
    // arrives, so a later colour-only change would repaint stale metrics.
    await tester.pumpWidget(
      nexusTestApp(
        PhoneBar(location: Nav.home.to, collapsed: collapsed, onExpand: () {}),
        overrides: [playerProvider.overrideWith(_PausedTrack.new)],
      ),
    );
    await tester.runAsync(GoogleFonts.pendingFonts);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerProvider.overrideWith(_PausedTrack.new)],
        child: MaterialApp.router(theme: buildNexusTheme(SectionKey.home.ambient), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final from = tester.getCenter(find.text(Nav.home.label));
    final to = tester.getCenter(find.text(Nav.f1.label));
    final drag = await tester.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await drag.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Nav.f1.to);
  });
}

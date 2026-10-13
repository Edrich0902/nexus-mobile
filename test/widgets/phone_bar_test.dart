import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
}

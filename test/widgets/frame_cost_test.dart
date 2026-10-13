import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/live_position.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/shell/phone_bar.dart';

import '../support/fakes.dart';

class _FixedPlayer extends PlayerController {
  new(this.playing);

  final bool playing;

  @override
  PlayerState build() => PlayerState(
    playback: {
      'is_playing': playing,
      'progress_ms': 1000,
      'item': {'duration_ms': 200000},
    },
    syncedAt: DateTime.now(),
  );
}

List<double> _barHeights(WidgetTester tester) => tester
    .widgetList<Container>(find.descendant(of: find.byType(NxEqualiser), matching: find.byType(Container)))
    .map((c) => c.constraints!.maxHeight)
    .toList();

void main() {
  testWidgets('the equaliser steps on a timer and never holds a vsync ticker', (tester) async {
    await tester.pumpWidget(nexusTestApp(const Center(child: NxEqualiser())));
    expect(tester.binding.transientCallbackCount, 0);

    final before = _barHeights(tester);
    await tester.pump(NxEqualiser.step);
    expect(_barHeights(tester), isNot(before));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the equaliser holds still under reduced motion', (tester) async {
    await tester.pumpWidget(
      nexusTestApp(const MediaQuery(data: MediaQueryData(disableAnimations: true), child: NxEqualiser())),
    );
    final before = _barHeights(tester);
    await tester.pump(NxEqualiser.step * 3);
    expect(_barHeights(tester), before);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the live track position steps on a timer only while playing', (tester) async {
    Future<int> builds(bool playing) async {
      var count = 0;
      await tester.pumpWidget(
        nexusTestApp(
          LiveTrackPosition(
            builder: (_, position, duration) {
              count++;
              return NxProgressRail(value: duration == 0 ? 0 : position / duration);
            },
          ),
          overrides: [playerProvider.overrideWith(() => _FixedPlayer(playing))],
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.binding.transientCallbackCount, 0);
      }
      await tester.pumpWidget(const SizedBox());
      return count;
    }

    expect(await builds(true), greaterThanOrEqualTo(4));
    expect(await builds(false), 1);
  });

  testWidgets('hour bars accept int counts typed as num', (tester) async {
    await tester.pumpWidget(nexusTestApp(const NxHourBars(<int>[0, 3, 9, 1])));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(nexusTestApp(const NxHourBars(<int>[0, 0])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the live dot rests between brief pulses', (tester) async {
    await tester.pumpWidget(nexusTestApp(const Center(child: NxLiveDot())));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.descendant(of: find.byType(NxLiveDot), matching: find.byType(RepaintBoundary)), findsOneWidget);
  });
}

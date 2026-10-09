import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/shell/phone_bar.dart';

import '../support/fakes.dart';

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

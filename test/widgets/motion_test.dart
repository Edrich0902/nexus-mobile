import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

import '../support/fakes.dart';

class _Counter extends StatefulWidget {
  const new();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => setState(() => taps++), child: Text('taps $taps'));
}

void main() {
  testWidgets('NxCountUp counts to the grouped value and leaves words alone', (tester) async {
    await tester.pumpWidget(
      nexusTestApp(
        Column(
          children: [
            NxCountUp('1,204', style: NxText.display()),
            NxCountUp('4d', style: NxText.display()),
          ],
        ),
      ),
    );
    expect(find.text('4d'), findsOneWidget);
    expect(find.text('1,204'), findsNothing, reason: 'starts from zero');
    await tester.pumpAndSettle();
    expect(find.text('1,204'), findsOneWidget);
  });

  testWidgets('NxRise settling late never rebuilds its child', (tester) async {
    Widget rise({required bool animate}) => nexusTestApp(NxRise(animate: animate, child: const _Counter()));
    await tester.pumpWidget(rise(animate: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('taps 0'));
    await tester.pump();
    await tester.pumpWidget(rise(animate: false));
    expect(find.text('taps 1'), findsOneWidget);
  });

  testWidgets('NxAsync cross-fades from loading to data and settles', (tester) async {
    Widget at(AsyncValue<String> v) =>
        nexusTestApp(NxAsync<String>(value: v, loading: const Text('loading'), data: Text.new));
    await tester.pumpWidget(at(const AsyncLoading()));
    expect(find.text('loading'), findsOneWidget);

    await tester.pumpWidget(at(const AsyncData('Chryseia')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Chryseia'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('loading'), findsNothing);
  });

  testWidgets('toasts replace each other, close on request and time out', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      nexusTestApp(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    showNxToast(ctx, 'Saved');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Saved'), findsOneWidget);

    final second = showNxToast(ctx, 'Could not save', error: true);
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Could not save'), findsOneWidget);

    second.close();
    await tester.pumpAndSettle();
    expect(find.text('Could not save'), findsNothing);

    showNxToast(ctx, 'Gone soon');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Gone soon'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Gone soon'), findsNothing);
  });
}

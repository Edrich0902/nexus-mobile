import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/meta/app_meta.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/shell/update_gate.dart';

import '../support/fakes.dart';

AppMeta _meta({required String min, String app = '1.0.0'}) =>
    AppMeta(minVersion: min, latestVersion: min, features: const {}, cloudName: null, appVersion: app);

void main() {
  testWidgets('UpdateGate passes through a supported build', (tester) async {
    await tester.pumpWidget(
      nexusTestApp(
        const UpdateGate(child: Text('app body')),
        overrides: [appMetaProvider.overrideWith((ref) async => _meta(min: '1.0.0'))],
      ),
    );
    await tester.pump();
    expect(find.text('app body'), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });

  testWidgets('UpdateGate blocks a build below the minimum', (tester) async {
    await tester.pumpWidget(
      nexusTestApp(
        const UpdateGate(child: Text('app body')),
        overrides: [appMetaProvider.overrideWith((ref) async => _meta(min: '1.2.0'))],
      ),
    );
    await tester.pump();
    expect(find.text('app body'), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.textContaining('Update to 1.2.0'), findsOneWidget);
  });

  test('storeUrl', () {
    expect(storeUrl(TargetPlatform.android), contains('id=app.nexus.nexus_mobile'));
    expect(storeUrl(TargetPlatform.iOS), isNull);
    expect(storeUrl(TargetPlatform.iOS, appStoreId: '123'), 'https://apps.apple.com/app/id123');
  });

  testWidgets('NxPressable is announced as a button and fires once', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      nexusTestApp(
        Center(
          child: NxPressable(semanticLabel: 'Open wine', onTap: () => taps++, child: const Text('Chryseia')),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(NxPressable)), containsSemantics(isButton: true, label: 'Open wine'));
    await tester.tap(find.text('Chryseia'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('empty and error states render their copy and actions', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      nexusTestApp(
        Column(
          children: [
            const NxEmptyState(title: 'No bottles yet', body: 'Log your first wine.'),
            NxErrorState(error: Exception('boom'), onRetry: () => retried++),
          ],
        ),
      ),
    );
    expect(find.text('No bottles yet'), findsOneWidget);
    expect(find.text('Log your first wine.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });
}

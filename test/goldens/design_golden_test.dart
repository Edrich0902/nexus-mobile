@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

import '../support/fakes.dart';

/// Keeps the mobile look in step with nexus-web. Regenerate after an
/// intentional design change: `flutter test --update-goldens --tags golden`.
void main() {
  testWidgets('home stage, colour fields and buttons', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      nexusTestApp(
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NxStage(
                compact: true,
                eyebrow: 'Tonight',
                title: 'Open the',
                accent: '2019 Chryseia',
                lede: 'Prats & Symington · Douro',
              ),
              NxBento(
                children: [
                  NxField(
                    span: 2,
                    bg: SectionKey.listening.field.bg,
                    label: 'Listening this week',
                    aside: 'Indie',
                    value: '412',
                    valueSize: 84,
                    sub: 'plays · 180 different tracks',
                  ),
                  NxField(bg: SectionKey.cellar.field.bg, label: 'Cellar', value: '38', sub: 'bottles'),
                  NxField(
                    variant: FieldVariant.tint,
                    bg: SectionKey.f1.field.bg,
                    label: 'Next race',
                    value: '4d',
                    sub: 'Singapore',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NxButton('Primary', onPressed: () {}),
                  NxButton('Secondary', variant: NxButtonVariant.secondary, onPressed: () {}),
                  NxButton('Ghost', variant: NxButtonVariant.ghost, onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('design_home.png'));
  });
}

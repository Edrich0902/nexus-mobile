import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/meta/app_meta.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

import '../support/fakes.dart';

const _meta = AppMeta(minVersion: '1.0.0', latestVersion: '1.0.0', features: {}, cloudName: null, appVersion: '1.0.0');

PrintModel _print(PrintArt art) => PrintModel(
  key: art.name,
  route: '/cellar/1',
  title: 'Endura Winemakers Selection Cape Blend',
  head: 'Red · 2019',
  artMode: art,
  src: 'https://images.example.com/label.jpg',
  icon: LucideIcons.wine,
  fallbackBg: const Color(0xFF5A1E2A),
  foot: 'Stellenbosch',
  notes: const ['cherry', 'oak'],
  rating: 4,
);

/// iPhone 17 logical size, where both bugs were first seen.
void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(402, 874) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('print cards with artwork lay out inside their intrinsic-height row', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      nexusTestApp(
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              for (final art in PrintArt.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NxPrintCard(print: _print(art), onTap: () {}),
                ),
            ],
          ),
        ),
        overrides: [appMetaProvider.overrideWith((ref) async => _meta)],
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(NxPrintCard), findsNWidgets(PrintArt.values.length));
    for (final card in tester.renderObjectList<RenderBox>(find.byType(NxPrintCard))) {
      expect(card.size.height, greaterThanOrEqualTo(220));
    }
  });

  testWidgets('print card art is delivered uncropped in every art mode', (tester) async {
    _phone(tester);
    const stored = 'https://res.cloudinary.com/nexus-hub/image/upload/v1/nexus/cellar/endura.jpg';
    await tester.pumpWidget(
      nexusTestApp(
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              for (final art in PrintArt.values)
                NxPrintCard(
                  print: PrintModel(
                    key: art.name,
                    route: '/cellar/1',
                    title: 'Endura Winemakers Selection Cape Blend',
                    head: 'Red · Coastal Region',
                    artMode: art,
                    src: stored,
                    icon: LucideIcons.wine,
                    fallbackBg: const Color(0xFF5A1E2A),
                    foot: 'Not tasted yet',
                  ),
                  onTap: () {},
                ),
            ],
          ),
        ),
        overrides: [appMetaProvider.overrideWith((ref) async => _meta)],
      ),
    );
    await tester.pump();

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, hasLength(PrintArt.values.length));
    for (final url in urls) {
      expect(url, contains('/t_nexus_hero/'), reason: 'fill crops (thumb/card) cut tall bottles and covers');
    }
  });

  testWidgets('a long field aside ellipsises instead of overflowing, label intact', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      nexusTestApp(
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: NxBento(
            children: [
              NxField(
                bg: SectionKey.cellar.field.bg,
                label: 'Cellar',
                aside: 'Endura Winemakers Selection Cape Blend',
                value: '38',
                sub: 'bottles',
              ),
              NxField(
                bg: SectionKey.f1.field.bg,
                label: 'P1 · Mercedes-AMG Petronas Formula One Team',
                aside: '+25 last round',
                value: '312',
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final cellar = tester.getRect(find.text('Cellar'));
    final aside = tester.getRect(find.text('Endura Winemakers Selection Cape Blend'));
    final field = tester.getRect(find.byType(NxField).first);
    expect(aside.right, lessThanOrEqualTo(field.right));
    expect(aside.left, greaterThan(cellar.right));
    expect(cellar.width, greaterThan(30), reason: 'the label keeps its natural width');
  });
}

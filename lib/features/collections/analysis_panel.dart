import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/drinks_api.dart';

/// "AI ready 2/3" pill (web NexusQuotaBadge).
class QuotaBadge extends ConsumerWidget {
  const QuotaBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(analysisQuotaProvider).value;
    if (quota == null) return const SizedBox.shrink();
    final c = context.nx;
    final models = quota.list('models');
    final available = models.where((m) => m.flag('available')).length;
    final ready = quota.flag('any_available');
    return Semantics(
      label: ready ? 'AI analysis is available' : 'All AI models are rate-limited right now',
      excludeSemantics: true,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(NxRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, size: 14, color: ready ? c.acc : c.ink4),
            const SizedBox(width: 6),
            Text(
              ready ? 'AI ready' : 'AI limited',
              style: NxText.sans(size: 13, weight: FontWeight.w500, color: c.ink2),
            ),
            const SizedBox(width: 6),
            Text('$available/${models.length}', style: NxText.sans(size: 12, color: c.ink4)),
          ],
        ),
      ),
    );
  }
}

/// AI tasting notes for a bottle (web NexusDrinkAnalysisPanel).
class AnalysisPanel extends StatelessWidget {
  const AnalysisPanel({
    required this.item,
    required this.analysing,
    required this.onAnalyse,
    super.key,
  });

  final Json item;
  final bool analysing;
  final ValueChanged<bool> onAnalyse;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final status = item.str('analysis_status');
    final analysis = item.obj('ai_analysis');
    final complete = status == 'complete' && analysis != null;
    final busy = status == 'pending' || analysing;
    final s = analysis?.obj('sensory');
    final n = analysis?.obj('narrative');

    Widget header() => NxSectionHeader(
      'Tasting notes',
      actionLabel: busy ? null : (complete ? 'Re-analyse' : 'Analyse'),
      onAction: busy ? null : () => onAnalyse(complete),
    );

    Widget note(String text, {required bool warn}) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn ? NexusColors.bad.withValues(alpha: .16) : c.acc.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(NxRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!warn) ...[
            const Padding(padding: EdgeInsets.only(top: 5), child: NxLiveDot()),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(text, style: NxText.sans(color: c.ink, height: 1.5)),
          ),
        ],
      ),
    );

    if (busy) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(),
          Semantics(
            liveRegion: true,
            child: note(
              'Reading the label and writing notes. This usually takes under a minute; a clear label photo helps.',
              warn: false,
            ),
          ),
        ],
      );
    }
    if (status == 'failed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header(), note(item.str('analysis_error') ?? 'Analysis failed. Try again.', warn: true)],
      );
    }
    if (!complete) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(),
          Text(
            'Run an analysis for aromas, flavours, structure, pairings and serving notes.',
            style: NxText.sans(size: 15, color: c.ink3, height: 1.45),
          ),
        ],
      );
    }

    final structure = <(String, String?)>[
      ('Appearance', s?.str('appearance')),
      ('Body', s?.str('body')),
      ('Sweetness', s?.str('sweetness')),
      ('Acidity', s?.str('acidity')),
      ('Tannin', s?.str('tannin')),
      ('Bitterness', s?.str('bitterness')),
      ('IBU', s?.str('bitterness_ibu')),
      ('Carbonation', s?.str('carbonation')),
      ('Smoke / peat', s?.str('smoke_peat')),
      ('Mouthfeel', s?.str('mouthfeel')),
      ('Finish', s?.str('finish')),
    ];
    final aromas = s?.strings('aroma_notes') ?? const [];
    final flavours = s?.strings('taste_notes') ?? const [];
    final character = n?.strings('characteristics') ?? const [];
    final facts = n?.strings('interesting_facts') ?? const [];
    final pairings = n?.strings('food_pairings') ?? const [];
    final serving = _servingLine(n);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(text.toUpperCase(), style: NxText.label(context, size: 11)),
    );
    Widget chips(List<String> items, {bool accent = true}) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final i in items) _Chip(i, accent: accent)],
    );
    Widget lines(List<String> items) => Column(
      children: [
        for (final i in items)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Text(i, style: NxText.sans(size: 14.5, color: c.ink2, height: 1.5)),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(),
        if (n?.str('tasting_notes') case final notes?)
          Text(notes, style: NxText.serif(size: 21, height: 1.3, color: c.ink).copyWith(letterSpacing: 0)),
        if (drinkProfile(_kind(analysis), analysis) case final profile?) ...[
          label('Profile'),
          Row(
            children: [
              NxRadar(profile.map((a) => a.value).toList()),
              const SizedBox(width: 16),
              Expanded(child: NxMeters(profile, labelWidth: 68)),
            ],
          ),
        ],
        if (aromas.isNotEmpty) ...[label('Aromas'), chips(aromas)],
        if (flavours.isNotEmpty) ...[label('Flavours'), chips(flavours)],
        if (structure.any((r) => r.$2 != null)) ...[label('Structure'), NxFacts(structure, columns: 2)],
        if (character.isNotEmpty) ...[label('Character'), lines(character)],
        if (facts.isNotEmpty) ...[label('Worth knowing'), lines(facts)],
        if (pairings.isNotEmpty) ...[label('Food pairings'), chips(pairings, accent: false)],
        if (serving != null)
          Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'SERVE   ', style: NxText.label(context, size: 11)),
                  TextSpan(text: serving),
                ],
              ),
              style: NxText.sans(size: 14.5, color: c.ink2, height: 1.5),
            ),
          ),
      ],
    );
  }

  static String _kind(Json? analysis) => switch (analysis?.str('domain')) {
    'beer' => 'beer',
    'spirit' => 'spirit',
    _ => 'wine',
  };

  static String? _servingLine(Json? n) {
    if (n == null) return null;
    final t = n.obj('serving_temp_c');
    final min = t?.number('min');
    final max = t?.number('max');
    String fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : '$v';
    final parts = [
      ?n.str('serving_suggestions'),
      ?n.str('glassware'),
      if (min != null && max != null)
        '${fmt(min)}–${fmt(max)}°C'
      else if (min != null)
        'from ${fmt(min)}°C'
      else if (max != null)
        'up to ${fmt(max)}°C',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.accent});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? c.acc.withValues(alpha: .16) : c.tint,
        borderRadius: BorderRadius.circular(NxRadius.pill),
      ),
      child: Text(label, style: NxText.sans(size: 13, color: accent ? c.ink : c.ink2)),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';

/// Port of web `design/profile.ts`: turn AI tasting words into 0–1 spokes.
class ProfileAxis {
  const new(this.label, this.value, this.word);

  final String label;
  final double value;
  final String word;
}

typedef _Ladder = List<(RegExp, double)>;

RegExp _r(String p) => RegExp(p);

final _Ladder _intensity = [
  (_r(r'\b(none|absent|nil|flat|still|no )'), .05),
  (_r('very (low|light|soft|subtle)|barely|trace'), .12),
  (_r('very (high|full|long|firm|intense)|massive|aggressive|huge|heavy|intense|powerful|explosive'), .92),
  (_r(r'medium[- ]?(plus|full|high|firm)|moderately high|med\+'), .68),
  (_r('medium[- ]?(minus|light|low|soft)|moderately low|med-'), .36),
  (_r(r'\b(medium|moderate|balanced|mid|average|integrated)'), .5),
  (
    _r(
      r'\b(high|full|bold|rich|firm|pronounced|strong|lively|effervescent|vibrant|bright|crisp|zesty|sharp|robust|big|grippy|assertive)',
    ),
    .82,
  ),
  (_r(r'\b(low|light|soft|gentle|subtle|faint|delicate|mild|slight|hint|touch|smooth|silky|round)'), .24),
];

final _Ladder _sweetness = [
  (_r('bone[- ]dry'), .03),
  (_r('off[- ]dry|semi[- ]dry|just dry'), .3),
  (_r('very sweet|luscious|syrupy|unctuous|dessert'), .92),
  (_r('medium[- ]sweet|semi[- ]sweet'), .6),
  (_r(r'\bsweet'), .78),
  (_r(r'\bdry'), .12),
];

final _Ladder _finish = [
  (_r('very long|endless|lingering for|extremely long'), .95),
  (_r('medium[- ]long|medium[- ]plus'), .68),
  (_r('medium[- ]short|medium[- ]minus'), .38),
  (_r(r'\blong|lingering|persistent'), .8),
  (_r(r'\bshort|brief|quick|clipped|snappy'), .26),
  (_r(r'\bmedium|moderate'), .52),
];

double? _climb(_Ladder ladder, String text) {
  for (final (re, v) in ladder) {
    if (re.hasMatch(text)) return v;
  }
  return null;
}

String _lead(String text) => text.split(RegExp('[,;/(]')).first.trim();

(double, String)? levelOf(String? text, [String kind = 'intensity']) {
  if (text == null || text.trim().isEmpty) return null;
  final t = text.toLowerCase();
  final head = _lead(t);
  final ladder = switch (kind) {
    'sweetness' => _sweetness,
    'finish' => _finish,
    _ => _intensity,
  };
  final v = _climb(ladder, head) ?? _climb(ladder, t) ?? _climb(_intensity, t);
  return v == null ? null : (v, _lead(text));
}

List<ProfileAxis>? _axes(List<String> labels, List<(double, String)?> levels) {
  if (levels.whereType<(double, String)>().length < 3) return null;
  return [
    for (var i = 0; i < labels.length; i++) ProfileAxis(labels[i], levels[i]?.$1 ?? 0, levels[i]?.$2 ?? 'unknown'),
  ];
}

double _clamp(double v) => math.min(1, math.max(.05, v));

/// Five spokes per drink; null when fewer than three can be read.
List<ProfileAxis>? drinkProfile(String kind, Json? analysis, {double? abv, double? ibu}) {
  final s = analysis?.obj('sensory');
  if (s == null) return null;
  final body = levelOf(s.str('body') ?? s.str('mouthfeel'));
  final sweet = levelOf(s.str('sweetness'), 'sweetness');
  final finish = levelOf(s.str('finish'), 'finish');

  if (kind == 'wine') {
    return _axes(
      ['Body', 'Tannin', 'Acidity', 'Sweetness', 'Finish'],
      [body, levelOf(s.str('tannin')), levelOf(s.str('acidity')), sweet, finish],
    );
  }
  if (kind == 'beer') {
    final i = s.number('bitterness_ibu') ?? ibu;
    final bitter = i != null ? (_clamp(i / 80), '${i.round()} IBU') : levelOf(s.str('bitterness'));
    return _axes(
      ['Body', 'Bitterness', 'Sweetness', 'Fizz', 'Finish'],
      [body, bitter, sweet, levelOf(s.str('carbonation')), finish],
    );
  }
  final a = abv ?? analysis?.obj('identity')?.number('abv');
  final strength = a != null ? (_clamp((a - 25) / 40), '${_trim(a)}%') : null;
  return _axes(
    ['Body', 'Sweetness', 'Smoke', 'Strength', 'Finish'],
    [body, sweet, levelOf(s.str('smoke_peat')), strength, finish],
  );
}

String _trim(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

/// Aroma then palate notes, lower-cased and de-duplicated.
List<String> drinkNotes(Json? analysis) {
  final s = analysis?.obj('sensory');
  if (s == null) return const [];
  final seen = <String>{};
  return [
    for (final n in [...s.strings('aroma_notes'), ...s.strings('taste_notes')])
      if (n.trim().isNotEmpty && seen.add(n.trim().toLowerCase())) n.trim().toLowerCase(),
  ];
}

/// Most frequent values across a collection, ties broken by first appearance.
List<String> topNotes(List<List<String>> lists, {int limit = 9}) {
  final counts = <String, int>{};
  for (final list in lists) {
    for (final n in list.toSet()) {
      counts[n] = (counts[n] ?? 0) + 1;
    }
  }
  final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(limit).map((e) => e.key).toList();
}

/// Artwork panel colour: a saturated swatch kept in a mid luminance range.
Color panelColour(Json? palette, Color fallback) {
  final pick = parseHex(palette?.str('vibrant') ?? palette?.str('muted') ?? palette?.str('dominant'));
  if (pick == null) return fallback;
  final l = pick.computeLuminance();
  if (l > .6) return shade(pick, -.12);
  if (l < .03) return shade(pick, .25);
  return pick;
}

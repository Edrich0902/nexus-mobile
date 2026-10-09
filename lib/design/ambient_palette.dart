import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The four colours the whole UI is tinted by (mirrors web `Ambient`).
@immutable
class Ambient {
  const Ambient({
    required this.amb,
    required this.amb2,
    required this.acc,
    required this.ink,
  });

  /// Page background.
  final Color amb;

  /// Raised surface / artwork well, one step lighter than [amb].
  final Color amb2;

  /// Accent: primary actions, italic headline words, live dots.
  final Color acc;

  /// Text colour on [amb].
  final Color ink;

  Ambient copyWith({Color? amb, Color? amb2, Color? acc, Color? ink}) => Ambient(
    amb: amb ?? this.amb,
    amb2: amb2 ?? this.amb2,
    acc: acc ?? this.acc,
    ink: ink ?? this.ink,
  );

  static Ambient lerp(Ambient a, Ambient b, double t) => Ambient(
    amb: Color.lerp(a.amb, b.amb, t)!,
    amb2: Color.lerp(a.amb2, b.amb2, t)!,
    acc: Color.lerp(a.acc, b.acc, t)!,
    ink: Color.lerp(a.ink, b.ink, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is Ambient && other.amb == amb && other.amb2 == amb2 && other.acc == acc && other.ink == ink;

  @override
  int get hashCode => Object.hash(amb, amb2, acc, ink);
}

/// Solid colour-field palette for a section (bg + legible text).
@immutable
class FieldColour {
  const FieldColour({required this.bg, required this.ink});

  final Color bg;
  final Color ink;
}

const _darkInk = Color(0xFF1A090D);
const _lightInk = Color(0xFFFBF5EF);

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Pick dark or light text for a solid background so contrast always holds.
Color inkFor(Color bg) => contrastRatio(bg, _darkInk) >= contrastRatio(bg, _lightInk) ? _darkInk : _lightInk;

/// Mix toward white (amount > 0) or black (amount < 0), like web `shade()`.
Color shade(Color c, double amount) {
  final t = amount.abs().clamp(0.0, 1.0);
  final target = amount >= 0 ? 1.0 : 0.0;
  double mix(double v) => v + (target - v) * t;
  return Color.from(alpha: c.a, red: mix(c.r), green: mix(c.g), blue: mix(c.b));
}

/// [fg] lifted (on dark) or deepened (on light) in small steps until it reads
/// against [bg], keeping its hue.
Color legibleOn(Color fg, Color bg, {double min = 4.5}) {
  final step = bg.computeLuminance() < .18 ? .15 : -.15;
  var c = fg;
  for (var i = 0; i < 10 && contrastRatio(c, bg) < min; i++) {
    c = shade(c, step);
  }
  return c;
}

/// `color-mix(in srgb, a p%, b)`.
Color mix(Color a, double p, Color b) => Color.lerp(b, a, p)!;

Color? parseHex(String? hex) {
  if (hex == null) return null;
  var raw = hex.trim().replaceFirst('#', '');
  if (raw.length == 3) raw = raw.split('').map((c) => '$c$c').join();
  if (raw.length < 6) return null;
  final v = int.tryParse(raw.substring(0, 6), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// Derive a legible dark ambient from artwork colours (mirrors web
/// `ambientFromPalette`): background pushed toward black, accent lifted until
/// it reads on that background.
Ambient ambientFromPalette({
  required Color dominant,
  required Color vibrant,
  required Color light,
}) {
  final amb = shade(dominant, -0.82);
  final amb2 = shade(dominant, -0.7);
  var acc = vibrant;
  for (var i = 0; i < 6 && contrastRatio(acc, amb) < 4.5; i++) {
    acc = shade(acc, 0.2);
  }
  final ink = shade(light, 0.85);
  return Ambient(
    amb: amb,
    amb2: amb2,
    acc: acc,
    ink: contrastRatio(ink, amb) >= 10 ? ink : const Color(0xFFF6EFE9),
  );
}

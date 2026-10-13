import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_mobile/design/colors.dart';

/// Type roles from web `theme.css` (`.nx-serif`, `.nx-display`, `.nx-mono`,
/// `.nx-eyebrow`, `.nx-label`).
abstract final class NxText {
  static TextStyle sans({double size = 14, FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontFeatures: const [FontFeature('cv11'), FontFeature('ss01')],
      );

  static TextStyle serif({double size = 40, Color? color, double height = .98, FontStyle? style}) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        color: color,
        height: height,
        letterSpacing: -.02 * size,
        fontStyle: style,
      );

  static TextStyle display({double size = 44, Color? color}) => GoogleFonts.bricolageGrotesque(
    fontSize: size,
    fontWeight: FontWeight.w800,
    letterSpacing: -.045 * size,
    height: .9,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle mono({double size = 11.5, Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

  static TextStyle eyebrow(BuildContext context) => sans(size: 13, weight: FontWeight.w500, color: context.nx.acc);

  static TextStyle label(BuildContext context, {double size = 12}) =>
      sans(size: size, weight: FontWeight.w600, color: context.nx.ink3).copyWith(letterSpacing: .08 * size);

  static TextStyle muted(BuildContext context, {double size = 13}) => sans(size: size, color: context.nx.ink3);
}

import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';

/// Derived surfaces + ink ramp, computed from the active [Ambient] exactly
/// like the `color-mix` variables in web `theme.css`.
@immutable
class NexusColors extends ThemeExtension<NexusColors> {
  const new({
    required this.amb,
    required this.amb2,
    required this.acc,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.line,
    required this.lineStrong,
    required this.tint,
    required this.tint2,
    required this.surface,
    required this.surface2,
    required this.overlay,
  });

  factory from(Ambient a) {
    Color alpha(Color c, double o) => c.withValues(alpha: o);
    return NexusColors(
      amb: a.amb,
      amb2: a.amb2,
      acc: a.acc,
      ink: a.ink,
      ink2: alpha(a.ink, .70),
      ink3: alpha(a.ink, .56),
      ink4: alpha(a.ink, .30),
      line: alpha(a.ink, .11),
      lineStrong: alpha(a.ink, .20),
      tint: alpha(a.ink, .06),
      tint2: alpha(a.ink, .10),
      surface: mix(a.ink, .05, a.amb),
      surface2: mix(a.ink, .09, a.amb),
      overlay: mix(a.amb, .80, Colors.black),
    );
  }

  final Color amb;
  final Color amb2;
  final Color acc;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color line;
  final Color lineStrong;
  final Color tint;
  final Color tint2;
  final Color surface;
  final Color surface2;
  final Color overlay;

  static const ok = Color(0xFF6FD39A);
  static const bad = Color(0xFFF08A7E);
  static const warn = Color(0xFFF2C46B);

  /// Text on the accent (buttons, selected chips).
  Color get accInk => amb;

  Ambient get ambient => Ambient(amb: amb, amb2: amb2, acc: acc, ink: ink);

  @override
  NexusColors copyWith() => this;

  @override
  NexusColors lerp(NexusColors? other, double t) {
    if (other == null) return this;
    return NexusColors.from(Ambient.lerp(ambient, other.ambient, t));
  }
}

extension NexusContext on BuildContext {
  NexusColors get nx => Theme.of(this).extension<NexusColors>()!;
}

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/widgets/nx_glass.dart';

ThemeData buildNexusTheme(Ambient ambient) {
  final c = NexusColors.from(ambient);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: c.amb,
    canvasColor: c.amb,
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.tint,
    colorScheme: ColorScheme.dark(
      primary: c.acc,
      onPrimary: c.amb,
      secondary: c.acc,
      onSecondary: c.amb,
      surface: c.amb,
      onSurface: c.ink,
      surfaceContainerHighest: c.surface2,
      surfaceContainerHigh: c.surface,
      surfaceContainer: c.surface,
      error: NexusColors.bad,
      outline: c.lineStrong,
      outlineVariant: c.line,
    ),
    extensions: [c],
  );

  final text = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: c.ink, displayColor: c.ink);

  return base.copyWith(
    textTheme: text,
    iconTheme: IconThemeData(color: c.ink2, size: 20),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.acc,
      selectionColor: c.acc.withValues(alpha: .3),
      selectionHandleColor: c.acc,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: nxWellFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: c.ink3),
      labelStyle: TextStyle(color: c.ink3),
      border: NxGlassBorder.recessed(c),
      enabledBorder: NxGlassBorder.recessed(c),
      disabledBorder: NxGlassBorder.recessed(c),
      focusedBorder: NxGlassBorder.solid(c.acc),
      errorBorder: NxGlassBorder.solid(NexusColors.bad, width: 1),
      focusedErrorBorder: NxGlassBorder.solid(NexusColors.bad),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.acc, linearTrackColor: c.line),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.overlay,
      contentTextStyle: TextStyle(color: c.ink, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NxRadius.md),
        side: BorderSide(color: c.line),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.overlay,
      surfaceTintColor: Colors.transparent,
      shape: NxGlassBorder.raised(c, radius: NxRadius.xxl + 6),
      headerForegroundColor: c.ink,
      todayBorder: BorderSide(color: c.acc),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.amb : c.ink3),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.acc : c.tint2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.ink,
      inactiveTrackColor: c.line,
      thumbColor: c.ink,
      trackHeight: 3,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: _OpaquePages(CupertinoPageTransitionsBuilder()),
        TargetPlatform.android: _OpaquePages(FadeForwardsPageTransitionsBuilder()),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: c.ink,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
  );
}

/// Platform page transitions over an opaque page. Shell pages draw no
/// background of their own, so without one the outgoing page shows through
/// the incoming one for the whole slide.
class _OpaquePages extends PageTransitionsBuilder {
  const new(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: child),
  );
}

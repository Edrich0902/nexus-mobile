import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Fonts come from assets/fonts (bundled), exactly like release builds.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}

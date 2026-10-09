import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_mobile/app.dart';
import 'package:nexus_mobile/core/errors/reporting.dart';

const _fontFamilies = ['Inter', 'InstrumentSerif', 'BricolageGrotesque', 'JetBrainsMono'];

Stream<LicenseEntry> _fontLicences() async* {
  for (final family in _fontFamilies) {
    yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
  }
}

Future<void> main() async {
  await Reporting.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Fonts ship in assets/fonts; never reach out to Google at runtime.
    GoogleFonts.config.allowRuntimeFetching = false;
    LicenseRegistry.addLicense(_fontLicences);
    // Artwork-heavy screens: cap decoded images so long sessions stay lean.
    PaintingBinding.instance.imageCache
      ..maximumSize = 300
      ..maximumSizeBytes = 160 << 20;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    runApp(const ProviderScope(child: NexusApp()));
  });
}

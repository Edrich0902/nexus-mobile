import 'package:flutter/material.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// Shown for the instant it takes to read the Keychain and call /auth/me.
class SplashScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Scaffold(
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NxLiveDot(size: 12, color: c.acc),
            const SizedBox(width: 12),
            Text(
              'Nexus',
              style: NxText.sans(size: 18, weight: FontWeight.w600, color: c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

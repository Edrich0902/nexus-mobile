import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:nexus_mobile/core/meta/app_meta.dart';
import 'package:nexus_mobile/core/native/open_external.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// Store page for this platform, or null when it isn't known yet (iOS
/// before the App Store id is configured).
String? storeUrl(TargetPlatform platform, {String appStoreId = AppConfig.appStoreId}) => switch (platform) {
  TargetPlatform.android => 'https://play.google.com/store/apps/details?id=${AppConfig.androidPackage}',
  TargetPlatform.iOS when appStoreId.isNotEmpty => 'https://apps.apple.com/app/id$appStoreId',
  _ => null,
};

/// Blocks the app when `GET /v1/meta` says this build is below the minimum
/// supported version (an API change the app can't speak yet).
class UpdateGate extends ConsumerWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(appMetaProvider).value;
    if (meta == null || !meta.updateRequired) return child;
    return _UpdateRequired(meta: meta);
  }
}

class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired({required this.meta});

  final AppMeta meta;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final url = storeUrl(defaultTargetPlatform);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update required', style: NxText.eyebrow(context)),
              const SizedBox(height: 14),
              Text('Time for a', style: NxText.serif(size: 48, color: c.ink)),
              Text(
                'new version',
                style: NxText.serif(size: 48, color: c.acc, style: FontStyle.italic),
              ),
              const SizedBox(height: 18),
              Text(
                'Nexus ${meta.appVersion} no longer works with the server. '
                'Update to ${meta.minVersion} or later to keep going — your data is safe.',
                style: NxText.sans(size: 17, color: c.ink2, height: 1.45),
              ),
              const Spacer(),
              if (url != null)
                NxButton(
                  'Open the store',
                  icon: LucideIcons.download,
                  wide: true,
                  onPressed: () => openExternal(url),
                )
              else
                Text('Install the latest build from TestFlight.', style: NxText.muted(context, size: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

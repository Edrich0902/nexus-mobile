import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/native/deep_links.dart';
import 'package:nexus_mobile/core/native/notifications.dart';
import 'package:quick_actions/quick_actions.dart';

typedef AppShortcut = ({String type, String title, String path, String icon});

/// Long-press app icon actions. Icons are `ic_shortcut_*` drawables on
/// Android and same-named image sets in the iOS asset catalogue.
const appShortcuts = <AppShortcut>[
  (type: 'log_wine', title: 'Log a wine', path: '/capture?kind=wine', icon: 'ic_shortcut_wine'),
  (type: 'log_beer', title: 'Log a beer', path: '/capture?kind=beer', icon: 'ic_shortcut_beer'),
  (type: 'scan_book', title: 'Scan a book', path: '/capture?kind=book&mode=barcode', icon: 'ic_shortcut_book'),
  (type: 'listening', title: 'Listening', path: '/spotify', icon: 'ic_shortcut_music'),
];

String? shortcutPath(String? type) => appShortcuts.where((s) => s.type == type).firstOrNull?.path;

final shortcutsProvider = Provider<AppShortcuts>(AppShortcuts.new);

class AppShortcuts {
  new(this._ref);

  final Ref _ref;
  bool _started = false;

  Future<void> start() async {
    if (_started || !isMobilePlatform) return;
    _started = true;
    const actions = QuickActions();
    try {
      await actions.initialize((type) {
        if (shortcutPath(type) case final path?) _ref.read(deepLinksProvider).open(path);
      });
      await actions.setShortcutItems([
        for (final s in appShortcuts) ShortcutItem(type: s.type, localizedTitle: s.title, icon: s.icon),
      ]);
    } on Object {
      // Shortcuts are a nicety; never block launch on them.
    }
  }
}

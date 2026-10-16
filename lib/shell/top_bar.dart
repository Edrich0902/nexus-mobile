import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/shell/account_sheet.dart';

/// Root destinations show the logo; anything deeper shows a back pill
/// labelled with its section (web NxTopBar on phones).
bool isRootPath(String path) {
  if (path == Nav.more.to || RegExp(r'^/sports/[a-z-]+$').hasMatch(path)) return true;
  return [...Nav.primary, ...Nav.secondary].any((d) => d.to == path);
}

Destination sectionDestination(String path) {
  final section = Nav.sectionFor(path);
  return [...Nav.primary, ...Nav.secondary].firstWhere((d) => d.section == section, orElse: () => Nav.home);
}

/// Floating glass islands over the page: the logo (or a back capsule
/// labelled with the section) on the left, capture and account on the right.
/// Search lives in the phone bar.
class TopBar extends ConsumerWidget {
  const new({required this.location, super.key});

  final String location;

  static const capsuleHeight = 44.0;
  static const gap = 4.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final mq = MediaQuery.of(context);
    final user = ref.watch(currentUserProvider);
    final root = isRootPath(location);
    final parent = sectionDestination(location);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, mq.padding.top + gap, 14, 0),
      child: Row(
        children: [
          NxSwitcher(
            alignment: Alignment.centerLeft,
            child: root
                ? Semantics(
                    key: const ValueKey('logo'),
                    button: true,
                    label: 'Nexus home',
                    excludeSemantics: true,
                    child: NxPressable(
                      onTap: () => context.go('/home'),
                      scale: .95,
                      child: NxGlass(
                        child: Container(
                          height: capsuleHeight,
                          padding: const EdgeInsets.only(left: 15, right: 17),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: c.acc, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                'Nexus',
                                style: NxText.sans(size: 15, weight: FontWeight.w600, color: c.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Semantics(
                    key: ValueKey('back:${parent.to}'),
                    button: true,
                    label: 'Back to ${parent.label}',
                    excludeSemantics: true,
                    child: NxPressable(
                      onTap: () => context.canPop() ? context.pop() : context.go(parent.to),
                      scale: .95,
                      child: NxGlass(
                        child: Container(
                          height: capsuleHeight,
                          padding: const EdgeInsets.only(left: 9, right: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.chevronLeft, size: 20, color: c.ink),
                              const SizedBox(width: 2),
                              Text(
                                parent.label,
                                style: NxText.sans(size: 15, weight: FontWeight.w500, color: c.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const Spacer(),
          NxGlass(
            child: SizedBox(
              height: capsuleHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NxIconButton(
                      LucideIcons.camera,
                      tooltip: 'Capture',
                      size: 36,
                      color: c.ink,
                      onPressed: () => context.push('/capture'),
                    ),
                    const SizedBox(width: 2),
                    Semantics(
                      button: true,
                      label: 'Account',
                      child: NxPressable(
                        onTap: () => showAccountSheet(context),
                        child: NxAvatar(user: user),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

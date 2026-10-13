import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/shell/account_sheet.dart';
import 'package:nexus_mobile/shell/app_shell.dart';
import 'package:nexus_mobile/shell/search_sheet.dart';

/// Root destinations show the logo; anything deeper shows a back pill
/// labelled with its section (web NxTopBar on phones).
bool isRootPath(String path) {
  if (RegExp(r'^/sports/[a-z-]+$').hasMatch(path)) return true;
  return [...Nav.primary, ...Nav.secondary].any((d) => d.to == path);
}

Destination sectionDestination(String path) {
  final section = Nav.sectionFor(path);
  return [...Nav.primary, ...Nav.secondary].firstWhere((d) => d.section == section, orElse: () => Nav.home);
}

class TopBar extends ConsumerWidget {
  const new({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final mq = MediaQuery.of(context);
    final user = ref.watch(currentUserProvider);
    final root = isRootPath(location);
    final parent = sectionDestination(location);

    return ClipRect(
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: mq.padding.top + topBarHeight,
          padding: EdgeInsets.fromLTRB(root ? 20 : 12, mq.padding.top, 12, 0),
          color: c.amb.withValues(alpha: .82),
          child: Row(
            children: [
              if (root)
                Semantics(
                  button: true,
                  label: 'Nexus home',
                  child: NxPressable(
                    onTap: () => context.go('/home'),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: c.acc, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Nexus',
                          style: NxText.sans(size: 15, weight: FontWeight.w600, color: c.ink),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Semantics(
                  button: true,
                  label: 'Back to ${parent.label}',
                  child: NxPressable(
                    onTap: () => context.canPop() ? context.pop() : context.go(parent.to),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.only(left: 6, right: 12),
                      decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(NxRadius.pill)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.chevronLeft, size: 18, color: c.ink2),
                          const SizedBox(width: 4),
                          Text(
                            parent.label,
                            style: NxText.sans(weight: FontWeight.w500, color: c.ink2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              NxIconButton(LucideIcons.camera, tooltip: 'Capture', onPressed: () => context.push('/capture')),
              NxIconButton(LucideIcons.search, tooltip: 'Search', onPressed: () => showSearchSheet(context)),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: 'Account',
                child: NxPressable(
                  onTap: () => showAccountSheet(context),
                  child: NxAvatar(user: user),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

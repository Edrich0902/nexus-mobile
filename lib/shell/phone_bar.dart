import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/player_sheet.dart';
import 'package:nexus_mobile/shell/more_sheet.dart';

/// Web NxDock at ≤640px: Spotify strip above a five-tab bar.
class PhoneBar extends ConsumerWidget {
  const PhoneBar({required this.location, super.key});

  final String location;

  static const tabsHeight = 58.0;
  static const stripHeight = 54.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final mq = MediaQuery.of(context);
    final hasTrack = ref.watch(playerProvider.select((p) => p.hasTrack));
    final inTabs = Nav.phoneTabs.any((d) => Nav.isActive(d, location));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.only(bottom: mq.padding.bottom),
          decoration: BoxDecoration(
            color: mix(c.amb, .88, Colors.black).withValues(alpha: .94),
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: NxMotion.ease,
                child: hasTrack ? const _Strip() : const SizedBox(width: double.infinity),
              ),
              SizedBox(
                height: tabsHeight,
                child: Row(
                  children: [
                    for (final d in Nav.phoneTabs)
                      _Tab(
                        icon: d.icon,
                        label: d.label,
                        active: Nav.isActive(d, location),
                        onTap: () => context.go(d.to),
                      ),
                    _Tab(
                      icon: LucideIcons.sparkles,
                      label: 'More',
                      active: !inTabs,
                      onTap: () => showMoreSheet(context, location),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final color = active ? c.acc : c.ink3;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: NxText.sans(size: 11, weight: FontWeight.w500, color: color),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Strip extends ConsumerWidget {
  const _Strip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final p = ref.watch(playerProvider);
    final device = p.device?.str('name');
    return Semantics(
      button: true,
      label: 'Now playing: ${p.title} by ${p.artists}. Open player',
      child: InkWell(
        onTap: () => showPlayerSheet(context),
        child: Container(
          height: PhoneBar.stripHeight,
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: NxImage(url: p.art, radius: 8, fallbackIcon: LucideIcons.music),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NxText.sans(size: 13.5, weight: FontWeight.w600, color: c.ink),
                        ),
                        Text(
                          [p.artists, ?device].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NxText.sans(size: 12, color: c.ink3),
                        ),
                      ],
                    ),
                  ),
                  if (p.isPlaying) const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: NxEqualiser()),
                  NxIconButton(
                    p.isPlaying ? LucideIcons.pause : LucideIcons.play,
                    tooltip: p.isPlaying ? 'Pause' : 'Play',
                    size: 34,
                    onPressed: p.busy ? null : () => ref.read(playerProvider.notifier).toggle(),
                  ),
                ],
              ),
              Positioned(
                left: -12,
                right: -6,
                bottom: -6,
                child: NxProgressRail(
                  value: p.progress,
                  height: 2,
                  color: const Color(0xFF1ED760),
                  track: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spotify-green three-bar equaliser.
class NxEqualiser extends StatefulWidget {
  const NxEqualiser({super.key});

  @override
  State<NxEqualiser> createState() => _NxEqualiserState();
}

class _NxEqualiserState extends State<NxEqualiser> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final phase in const [0.0, .7, .4])
              Container(
                width: 3,
                height: 4 + 10 * (1 - ((_c.value + phase) % 1 * 2 - 1).abs()),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: const Color(0xFF1ED760), borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }
}

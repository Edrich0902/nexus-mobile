import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/f1/f1.dart';
import 'package:nexus_mobile/features/f1/f1_widgets.dart';

/// Web F1View: countdown stage, championship podium, the weekend timeline,
/// the rest of the field, constructors and the season calendar.
class F1Screen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<F1Screen> createState() => _F1ScreenState();
}

class _F1ScreenState extends ConsumerState<F1Screen> {
  bool _allDrivers = false;
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await syncF1(context, ref);
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(f1SeasonProvider);
    final now = ref.watch(f1ClockProvider).value ?? DateTime.now();
    final health = ref.watch(f1StatusProvider).value?.obj('provider_health');

    return NxPage(
      onRefresh: () async {
        ref
          ..invalidate(f1SeasonProvider)
          ..invalidate(f1StatusProvider);
        await ref.read(f1SeasonProvider.future);
      },
      children: [
        NxAsync(
          value: async,
          onRetry: () => ref.invalidate(f1SeasonProvider),
          loading: const _Loading(),
          data: (data) {
            final meetings = data.season.list('meetings');
            if (meetings.isEmpty) {
              return Column(
                children: [
                  const NxStage(eyebrow: 'Formula 1', title: 'The', accent: 'season'),
                  F1LockoutBanner(health: health),
                  const SizedBox(height: 22),
                  NxEmptyState(
                    icon: LucideIcons.flag,
                    title: 'No season data yet',
                    body: 'Run a sync to pull the calendar and standings from OpenF1.',
                    actionLabel: 'Sync now',
                    onAction: _syncing ? null : _sync,
                  ),
                ],
              );
            }
            return _Season(
              season: data.season,
              standings: data.standings,
              now: now,
              health: health,
              allDrivers: _allDrivers,
              onToggleDrivers: () => setState(() => _allDrivers = !_allDrivers),
              syncing: _syncing,
              onSync: _sync,
            );
          },
        ),
      ],
    );
  }
}

class _Season extends StatelessWidget {
  const new({
    required this.season,
    required this.standings,
    required this.now,
    required this.health,
    required this.allDrivers,
    required this.onToggleDrivers,
    required this.syncing,
    required this.onSync,
  });

  final Json season;
  final Json standings;
  final DateTime now;
  final Json? health;
  final bool allDrivers;
  final VoidCallback onToggleDrivers;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final meetings = season.list('meetings');
    final drivers = standings.list('drivers');
    final teams = standings.list('teams');
    final leaderPoints = drivers.firstOrNull?.number('points') ?? 0;
    final championship = rounds(meetings);
    final year = season.integer('year');

    final next = meetings
        .where((m) => !m.flag('is_cancelled') && meetingState(m, now) != SessionState.done)
        .firstOrNull;
    final roundIndex = next == null
        ? -1
        : championship.indexWhere((r) => r.integer('meeting_key') == next.integer('meeting_key'));
    final focus = next == null ? null : focusSession(next.list('sessions'), now);
    final focusStart = DateTime.tryParse(focus?.text('date_start') ?? '');
    final live = focusStart != null && !focusStart.isAfter(now);

    final (String title, String accent) = switch (next) {
      null => ('${year ?? ''} season', 'complete'),
      _ when focus != null && live => (focus.text('session_name'), 'is live'),
      final m =>
        countdown(focus?.str('date_start') ?? m.str('date_start'), now) ?? (m.text('meeting_name'), 'this weekend'),
    };

    final eyebrow = next == null
        ? 'Formula 1'
        : [
            if (roundIndex >= 0) 'Round ${roundIndex + 1} of ${championship.length}' else 'Testing',
            next.text('meeting_name'),
            if (focus != null && live) 'On track now' else if (focus != null) '${focus.text('session_name')} in',
          ].join(' · ');

    final lede = () {
      final place = next == null ? null : meetingPlace(next);
      final race = place == null || place.isEmpty ? '' : '$place, ${meetingDates(next!)}.';
      final p1 = drivers.firstOrNull;
      final p2 = drivers.elementAtOrNull(1);
      if (p1 == null) return race.isEmpty ? 'Sync to pull the season calendar and standings.' : race;
      if (next == null) {
        return '${driverName(p1.str('name'))} took the title with ${p1.number('points')?.round() ?? 0} points.';
      }
      if (p2 == null) return '$race ${surname(p1.str('name'))} leads the championship.';
      final gap = ((p1.number('points') ?? 0) - (p2.number('points') ?? 0)).round();
      return '$race ${surname(p1.str('name'))} leads ${surname(p2.str('name'))} by $gap point${gap == 1 ? '' : 's'}.';
    }();

    final rest = drivers.skip(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxStage(
          live: live,
          eyebrow: eyebrow,
          title: title,
          accent: accent,
          lede: lede,
          visual: F1Circuit(url: next?.str('circuit_image')),
          actions: [
            if (next != null)
              NxButton(
                'Open the weekend',
                onPressed: () => context.push('/f1/meetings/${next.integer('meeting_key')}'),
              ),
            NxButton(
              'Sync',
              icon: LucideIcons.refreshCw,
              variant: NxButtonVariant.secondary,
              loading: syncing,
              onPressed: onSync,
            ),
          ],
        ),
        if (drivers.isNotEmpty)
          NxBento(
            children: [
              for (final (i, d) in drivers.take(3).indexed)
                NxField(
                  bg: teamColour(d.str('team_colour')),
                  span: i == 0 ? 2 : 1,
                  minHeight: i == 0 ? 140 : 120,
                  label:
                      'P${d.integer('position') ?? i + 1}${d.str('team_name') == null ? '' : ' · ${d.str('team_name')}'}',
                  aside: switch ((d.number('points') ?? 0) - (d.number('points_start') ?? d.number('points') ?? 0)) {
                    final gained when gained > 0 => '+${gained.round()} last round',
                    _ when i > 0 => '−${(leaderPoints - (d.number('points') ?? 0)).round()}',
                    _ => 'Leader',
                  },
                  value: '${d.number('points')?.round() ?? 0}',
                  valueSize: i == 0 ? 60 : 44,
                  sub: driverName(d.str('name'), '#${d.integer('driver_number')}'),
                ),
            ],
          ),
        F1LockoutBanner(health: health),
        if (next != null && next.list('sessions').isNotEmpty) ...[
          NxSectionHeader(
            '${next.text('meeting_name')} · your time',
            actionLabel: 'Weekend detail',
            onAction: () => context.push('/f1/meetings/${next.integer('meeting_key')}'),
          ),
          F1Weekend(sessions: next.list('sessions'), now: now),
        ],
        if (rest.isNotEmpty) ...[
          NxSectionHeader(
            'The rest of the field',
            actionLabel: drivers.length > 10 ? (allDrivers ? 'Show fewer' : 'Show all') : null,
            onAction: onToggleDrivers,
          ),
          F1DriverRows(drivers: allDrivers ? rest : rest.take(7).toList(), leaderPoints: leaderPoints),
        ],
        if (teams.isNotEmpty) ...[
          const NxSectionHeader('Constructors'),
          F1ConstructorBars(teams: teams, colours: teamColours(drivers)),
        ],
        NxSectionHeader('Calendar · ${year ?? ''}'),
        F1Calendar(meetings: meetings, now: now),
        Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Text(
            'Historical data from OpenF1. Live timing needs a paid subscription, so session results land about '
            '35 minutes after the chequered flag.',
            style: NxText.sans(size: 13, color: c.ink3, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      NxSkeleton(height: 132, width: 132, radius: NxRadius.lg),
      SizedBox(height: 20),
      NxSkeleton(height: 90, radius: NxRadius.md),
      SizedBox(height: 22),
      NxSkeleton(height: 140, radius: NxRadius.lg),
      SizedBox(height: 22),
      NxSkeleton(height: 260, radius: NxRadius.lg),
    ],
  );
}

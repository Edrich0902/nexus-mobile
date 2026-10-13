import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/f1/f1.dart';

/// Circuit map on a light plate: OpenF1 maps are dark lines meant for white pages.
class F1Circuit extends StatelessWidget {
  const new({this.url, super.key});

  final String? url;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF4F1EC),
    child: url == null
        ? const Center(child: Icon(LucideIcons.flag, size: 56, color: Color(0xFF6B6B6B)))
        : Padding(
            padding: const EdgeInsets.all(18),
            child: NxImage(url: url, fit: BoxFit.contain, fallbackIcon: LucideIcons.flag),
          ),
  );
}

/// "Data paused while a session is live" (web NexusF1LockoutBanner).
class F1LockoutBanner extends StatelessWidget {
  const new({required this.health, super.key});

  final Json? health;

  @override
  Widget build(BuildContext context) {
    final h = health;
    if (h == null || !h.flag('live_lockout')) return const SizedBox.shrink();
    final c = context.nx;
    final until = DateTime.tryParse(h.text('locked_until'))?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: NxPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.clock, size: 18, color: c.acc),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Data paused while a session is live. ',
                      style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                    ),
                    TextSpan(
                      text:
                          "OpenF1's free tier locks during live sessions; syncing resumes on its own${until == null ? '' : ' around ${DateFormat('HH:mm').format(until)}'}.",
                    ),
                    if (h.str('reason') case final reason?)
                      TextSpan(
                        text: ' $reason',
                        style: TextStyle(color: c.ink3),
                      ),
                  ],
                ),
                style: NxText.sans(size: 13.5, color: c.ink2, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A race weekend as a horizontal timeline in the viewer's timezone.
class F1Weekend extends StatelessWidget {
  const new({required this.sessions, required this.now, super.key});

  final List<Json> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final list = sessions.where((s) => !s.flag('is_cancelled')).toList();
    final focus = focusSession(list, now);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = list[i];
          final state = sessionState(s, focus, now);
          final highlight = state == SessionState.live || state == SessionState.next;
          return NxPressable(
            onTap: () => context.push('/f1/sessions/${s.integer('session_key')}'),
            child: Container(
              width: 136,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: highlight ? c.ink : (state == SessionState.done ? c.tint : c.surface2),
                borderRadius: BorderRadius.circular(NxRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.text('session_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(
                      weight: FontWeight.w600,
                      color: highlight ? c.amb : (state == SessionState.done ? c.ink3 : c.ink),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sessionWhen(s.str('date_start')),
                    style: NxText.mono(color: highlight ? c.amb.withValues(alpha: .75) : c.ink3),
                  ),
                  const Spacer(),
                  if (switch (state) {
                        SessionState.done => 'Finished',
                        SessionState.live => 'Live now',
                        SessionState.next => 'Up next',
                        SessionState.upcoming => null,
                      }
                      case final label?)
                    Row(
                      children: [
                        if (state == SessionState.live) ...[NxLiveDot(color: c.acc, size: 6), const SizedBox(width: 6)],
                        Text(
                          label,
                          style: NxText.sans(size: 12, weight: FontWeight.w600, color: highlight ? c.acc : c.ink3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Driver standings as hairline rows: position, team bar, name, points, gap.
class F1DriverRows extends StatelessWidget {
  const new({required this.drivers, required this.leaderPoints, super.key});

  final List<Json> drivers;
  final num leaderPoints;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Column(
      children: [
        for (var i = 0; i < drivers.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text('P${drivers[i].integer('position') ?? '–'}', style: NxText.mono(color: c.ink3)),
                ),
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: teamColour(drivers[i].str('team_colour')),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: driverName(drivers[i].str('name'), '#${drivers[i].integer('driver_number')}'),
                          style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                        ),
                        if (drivers[i].str('team_name') case final team?)
                          TextSpan(
                            text: ' · $team',
                            style: NxText.sans(size: 13, color: c.ink3),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${drivers[i].number('points')?.round() ?? 0}',
                  style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    switch (leaderPoints - (drivers[i].number('points') ?? 0)) {
                      final gap when gap > 0 => '−${gap.round()}',
                      _ => '',
                    },
                    textAlign: TextAlign.right,
                    style: NxText.mono(color: c.ink3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Constructor standings as bars in team colours, scaled to the leader.
class F1ConstructorBars extends StatelessWidget {
  const new({required this.teams, required this.colours, super.key});

  final List<Json> teams;
  final Map<String, Color> colours;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final max = teams.fold<double>(1, (m, t) => math.max(m, t.number('points') ?? 0));
    return Column(
      children: [
        for (final t in teams)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    t.text('team_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 13, color: c.ink2),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, box) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 10,
                        width: math.max(3, box.maxWidth * (t.number('points') ?? 0) / max),
                        decoration: BoxDecoration(
                          color: colours[t.str('team_name')] ?? c.ink3,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${t.number('points')?.round() ?? 0}',
                    textAlign: TextAlign.right,
                    style: NxText.sans(size: 13, weight: FontWeight.w600, color: c.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The season calendar; finished rounds dim, the live one glows.
class F1Calendar extends StatelessWidget {
  const new({required this.meetings, required this.now, super.key});

  final List<Json> meetings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    var round = 0;
    final rows = [
      for (final m in meetings)
        (
          meeting: m,
          label: isTesting(m)
              ? 'Test'
              : m.flag('is_cancelled')
              ? '—'
              : 'R${(++round).toString().padLeft(2, '0')}',
          state: m.flag('is_cancelled') ? null : meetingState(m, now),
        ),
    ];
    final nextKey = rows
        .where((r) => r.state == SessionState.live || r.state == SessionState.upcoming)
        .firstOrNull
        ?.meeting
        .integer('meeting_key');
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: () => context.push('/f1/meetings/${rows[i].meeting.integer('meeting_key')}'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
              ),
              child: Opacity(
                opacity: rows[i].state == SessionState.done || rows[i].state == null ? .55 : 1,
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        rows[i].label,
                        style: NxText.mono(
                          color: rows[i].meeting.integer('meeting_key') == nextKey ? c.acc : c.ink3,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[i].meeting.text('meeting_name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                          ),
                          Text(
                            [?rows[i].meeting.str('location'), ?rows[i].meeting.str('country_name')].join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NxText.sans(size: 12.5, color: c.ink3),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(meetingDates(rows[i].meeting), style: NxText.sans(size: 13, color: c.ink2)),
                        if (rows[i].state == SessionState.live)
                          Text(
                            'Live',
                            style: NxText.sans(size: 12, weight: FontWeight.w600, color: c.acc),
                          )
                        else if (rows[i].meeting.integer('meeting_key') == nextKey)
                          Text(
                            'Next',
                            style: NxText.sans(size: 12, weight: FontWeight.w600, color: c.acc),
                          )
                        else if (rows[i].state == null)
                          Text('Cancelled', style: NxText.sans(size: 12, color: c.ink3)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

const _compounds = {
  'SOFT': (Color(0xFFFF3B30), 'S'),
  'MEDIUM': (Color(0xFFFFD12E), 'M'),
  'HARD': (Color(0xFFF0EFE9), 'H'),
  'INTERMEDIATE': (Color(0xFF43B047), 'I'),
  'WET': (Color(0xFF2F7FE0), 'W'),
};

/// Tyre strategy: one lane per driver, stints as compound-coloured segments.
class F1Stints extends StatelessWidget {
  const new({required this.stints, required this.order, required this.label, super.key});

  final List<Json> stints;

  /// Driver numbers in finishing order; drivers missing here sort last.
  final List<int> order;
  final String Function(int driverNumber) label;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final totalLaps = stints.fold<int>(1, (m, s) => math.max(m, s.integer('lap_end') ?? 0));
    final byDriver = <int, List<Json>>{};
    for (final s in stints) {
      byDriver.putIfAbsent(s.integer('driver_number') ?? 0, () => []).add(s);
    }
    int rank(int n) => order.contains(n) ? order.indexOf(n) : 1 << 30;
    final lanes = byDriver.entries.toList()
      ..sort((a, b) => rank(a.key) != rank(b.key) ? rank(a.key) - rank(b.key) : a.key - b.key);
    final used = {for (final s in stints) s.text('compound').toUpperCase()};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final MapEntry(key: name, value: (colour, _)) in _compounds.entries)
              if (used.contains(name))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(name.toLowerCase(), style: NxText.sans(size: 12, color: c.ink2)),
                  ],
                ),
            Text('$totalLaps laps', style: NxText.mono(color: c.ink3)),
          ],
        ),
        const SizedBox(height: 12),
        for (final lane in lanes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(label(lane.key), style: NxText.mono(color: c.ink2)),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, box) => SizedBox(
                      height: 16,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          for (final s
                              in lane.value.where((s) => s.integer('lap_start') != null).toList()
                                ..sort((a, b) => (a.integer('stint_number') ?? 0) - (b.integer('stint_number') ?? 0)))
                            Positioned(
                              left: box.maxWidth * ((s.integer('lap_start')! - 1) / totalLaps),
                              width: math.max(
                                2,
                                box.maxWidth *
                                    (((s.integer('lap_end') ?? s.integer('lap_start')!) - s.integer('lap_start')! + 1) /
                                        totalLaps),
                              ),
                              top: 0,
                              bottom: 0,
                              child: Tooltip(
                                message:
                                    '${s.text('compound', 'Unknown')} · laps ${s.integer('lap_start')}–${s.integer('lap_end') ?? s.integer('lap_start')}',
                                child: Container(
                                  margin: const EdgeInsets.only(right: 1),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _compounds[s.text('compound').toUpperCase()]?.$1 ?? c.ink3,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _compounds[s.text('compound').toUpperCase()]?.$2 ?? '?',
                                    style: NxText.mono(size: 9.5, color: Colors.black87, weight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A compact read-only table for session data (results, grid, pits, …).
class F1Table extends StatelessWidget {
  const new({required this.columns, required this.rows, this.flex, super.key});

  final List<String> columns;
  final List<List<Widget>> rows;
  final List<int>? flex;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final widths = flex ?? List.filled(columns.length, 1);
    Widget cells(List<Widget> children, {bool head = false}) => Row(
      children: [
        for (var i = 0; i < children.length; i++)
          Expanded(
            flex: widths[i],
            child: Align(alignment: Alignment.centerLeft, child: children[i]),
          ),
      ],
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: cells([for (final h in columns) Text(h, style: NxText.label(context))], head: true),
        ),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: cells(r),
          ),
      ],
    );
  }
}

/// Team-colour bar plus driver label for table cells.
class F1DriverCell extends StatelessWidget {
  const new({required this.colour, required this.name, this.team, super.key});

  final Color colour;
  final String name;
  final String? team;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: NxText.sans(size: 13.5, weight: FontWeight.w600, color: c.ink),
                ),
                if (team != null)
                  TextSpan(
                    text: '  $team',
                    style: NxText.sans(size: 12, color: c.ink3),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

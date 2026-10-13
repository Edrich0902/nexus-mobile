import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/f1/f1.dart';
import 'package:nexus_mobile/features/f1/f1_widgets.dart';

enum _Tab { results, grid, stints, pits, control, positions }

const _pageSize = 25;

const _flagTone = {
  'GREEN': NexusColors.ok,
  'CLEAR': NexusColors.ok,
  'YELLOW': NexusColors.warn,
  'DOUBLE YELLOW': NexusColors.warn,
  'RED': NexusColors.bad,
  'BLUE': Color(0xFF5B9FD4),
};

/// Results ordered by classification, then retirements by laps completed.
List<Json> sortResults(List<Json> results) => [...results]
  ..sort((a, b) {
    final (pa, pb) = (a.integer('position'), b.integer('position'));
    if (pa != null && pb != null) return pa - pb;
    if (pa != null) return -1;
    if (pb != null) return 1;
    return (b.integer('number_of_laps') ?? 0) - (a.integer('number_of_laps') ?? 0);
  });

/// "21–24°C" from weather samples, or a single value when steady.
String? weatherRange(List<Json> samples, String key, String unit) {
  final v = [for (final w in samples) ?w.number(key)];
  if (v.isEmpty) return null;
  final (lo, hi) = (v.reduce(math.min).round(), v.reduce(math.max).round());
  return lo == hi ? '$lo$unit' : '$lo–$hi$unit';
}

/// Web F1SessionView: winner headline, podium, and tabbed timing data.
class F1SessionScreen extends ConsumerStatefulWidget {
  const new({required this.sessionKey, super.key});

  final int sessionKey;

  @override
  ConsumerState<F1SessionScreen> createState() => _F1SessionScreenState();
}

class _F1SessionScreenState extends ConsumerState<F1SessionScreen> {
  _Tab _tab = _Tab.results;
  int _limit = _pageSize;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(f1SessionProvider(widget.sessionKey));
    final health = ref.watch(f1StatusProvider).value?.obj('provider_health');

    return NxPage(
      onRefresh: () async {
        ref.invalidate(f1SessionProvider(widget.sessionKey));
        await ref.read(f1SessionProvider(widget.sessionKey).future);
      },
      children: [
        NxAsync(
          value: async,
          onRetry: () => ref.invalidate(f1SessionProvider(widget.sessionKey)),
          data: (data) => _body(context, data.detail, data.analysis, health),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, Json detail, Json analysis, Json? health) {
    final c = context.nx;
    final session = detail.obj('session') ?? const {};
    final drivers = {for (final d in detail.list('drivers')) d.integer('driver_number') ?? 0: d};
    String acronym(int n) => drivers[n]?.str('name_acronym') ?? '#$n';
    String fullName(int n) => driverName(drivers[n]?.str('full_name'), '#$n');
    Color colourOf(int n) => teamColour(drivers[n]?.str('team_colour'));

    final results = sortResults(detail.list('results'));
    final grid = [...detail.list('starting_grid')]
      ..sort((a, b) => (a.integer('position') ?? 99) - (b.integer('position') ?? 99));
    final type = session.text('session_type').toLowerCase();

    final winner = results.firstOrNull;
    final (String title, String? accent) = () {
      final name = session.text('session_name', 'Session');
      if (winner == null || winner.integer('position') != 1) return (name, null);
      final n = winner.integer('driver_number') ?? 0;
      final who = surname(drivers[n]?.str('full_name')).isEmpty ? acronym(n) : surname(drivers[n]?.str('full_name'));
      return (who, type == 'race' ? 'wins' : (type == 'qualifying' ? 'on pole' : 'fastest'));
    }();

    final lede = () {
      if (detail.flag('detail_synced')) {
        final laps = results.fold<int>(0, (m, r) => math.max(m, r.integer('number_of_laps') ?? 0));
        final outs = results.where((r) => r.flag('dnf') || r.flag('dns') || r.flag('dsq')).length;
        return '${['${results.length} drivers', if (laps > 0) '$laps laps', if (outs > 0) '$outs did not finish'].join(' · ')}.';
      }
      if (detail.flag('detail_available')) return 'Session data is being prepared. Check back in a few minutes.';
      return 'Results arrive about 35 minutes after the session ends.';
    }();

    final stints = analysis.list('stints');
    final pits = analysis.list('pits');
    final control = analysis.list('race_control');
    final positions = analysis.list('positions');
    final weather = analysis.list('weather');
    final counts = {
      _Tab.results: results.length,
      _Tab.grid: grid.length,
      _Tab.stints: stints.length,
      _Tab.pits: pits.length,
      _Tab.control: control.length,
      _Tab.positions: positions.length,
    };
    final tabs = [
      for (final t in _Tab.values)
        if (t == _Tab.results || (counts[t] ?? 0) > 0)
          (
            t,
            switch (t) {
              _Tab.results => 'Results',
              _Tab.grid => 'Grid',
              _Tab.stints => 'Tyres',
              _Tab.pits => 'Pit stops',
              _Tab.control => 'Race control',
              _Tab.positions => 'Positions',
            },
          ),
    ];
    final tab = tabs.any((t) => t.$1 == _tab) ? _tab : _Tab.results;

    final podium = results.where((r) => (r.integer('position') ?? 99) <= 3).toList();

    Widget more(int total) => total > _limit
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: NxButton(
              'Show more',
              variant: NxButtonVariant.ghost,
              onPressed: () => setState(() => _limit += _pageSize),
            ),
          )
        : const SizedBox.shrink();

    final table = switch (tab) {
      _Tab.results => F1Table(
        columns: const ['Pos', 'Driver', 'Time / gap', 'Laps'],
        flex: const [2, 7, 5, 2],
        rows: [
          for (final r in results)
            [
              Text(
                '${r.integer('position') ?? (r.flag('dsq') ? 'DSQ' : (r.flag('dns') ? 'DNS' : 'DNF'))}',
                style: NxText.mono(color: c.ink2),
              ),
              F1DriverCell(
                colour: colourOf(r.integer('driver_number') ?? 0),
                name: acronym(r.integer('driver_number') ?? 0),
                team: drivers[r.integer('driver_number')]?.str('team_name'),
              ),
              Text(
                r.integer('position') == 1 ? timing(r['duration']) : timing(r['gap_to_leader'], gap: true),
                style: NxText.mono(color: c.ink),
              ),
              Text('${r.integer('number_of_laps') ?? '—'}', style: NxText.sans(size: 13, color: c.ink2)),
            ],
        ],
      ),
      _Tab.grid => F1Table(
        columns: const ['Pos', 'Driver', 'Qualifying lap'],
        flex: const [2, 8, 5],
        rows: [
          for (final g in grid)
            [
              Text('${g.integer('position') ?? '—'}', style: NxText.mono(color: c.ink2)),
              F1DriverCell(
                colour: colourOf(g.integer('driver_number') ?? 0),
                name: fullName(g.integer('driver_number') ?? 0),
              ),
              Text(timing(g['lap_duration']), style: NxText.mono(color: c.ink)),
            ],
        ],
      ),
      _Tab.stints => F1Stints(
        stints: stints,
        order: [for (final r in results) r.integer('driver_number') ?? 0],
        label: acronym,
      ),
      _Tab.pits => F1Table(
        columns: const ['Driver', 'Lap', 'Stop', 'Pit lane'],
        flex: const [4, 2, 3, 3],
        rows: [
          for (final p in pits)
            [
              F1DriverCell(
                colour: colourOf(p.integer('driver_number') ?? 0),
                name: acronym(p.integer('driver_number') ?? 0),
              ),
              Text('${p.integer('lap_number') ?? '—'}', style: NxText.sans(size: 13, color: c.ink2)),
              Text(
                p.number('stop_duration') == null ? '—' : '${p.number('stop_duration')}s',
                style: NxText.mono(color: c.ink),
              ),
              Text(
                p.number('lane_duration') == null ? '—' : '${p.number('lane_duration')}s',
                style: NxText.mono(color: c.ink),
              ),
            ],
        ],
      ),
      _Tab.control => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          F1Table(
            columns: const ['Time', 'Lap', 'Message'],
            flex: const [3, 2, 11],
            rows: [
              for (final r in control.take(_limit))
                [
                  Text(timeOfDay(r.str('date')), style: NxText.mono(color: c.ink3)),
                  Text('${r.integer('lap_number') ?? '—'}', style: NxText.sans(size: 13, color: c.ink2)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.str('flag') case final flag?)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 8),
                          child: Tooltip(
                            message: flag,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: flag == 'CHEQUERED' ? c.ink : (_flagTone[flag] ?? c.ink3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(r.text('message'), style: NxText.sans(size: 13, color: c.ink, height: 1.4)),
                      ),
                    ],
                  ),
                ],
            ],
          ),
          more(control.length),
        ],
      ),
      _Tab.positions => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          F1Table(
            columns: const ['Time', 'Driver', 'Now P'],
            flex: const [3, 6, 2],
            rows: [
              for (final p in positions.reversed.take(math.min(200, _limit)))
                [
                  Text(timeOfDay(p.str('date')), style: NxText.mono(color: c.ink3)),
                  F1DriverCell(
                    colour: colourOf(p.integer('driver_number') ?? 0),
                    name: acronym(p.integer('driver_number') ?? 0),
                  ),
                  Text('${p.integer('position') ?? '—'}', style: NxText.sans(size: 13, color: c.ink)),
                ],
            ],
          ),
          if (_limit < 200) more(math.min(200, positions.length)),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('The latest 200 position changes, newest first.', style: NxText.muted(context, size: 12.5)),
          ),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxStage(
          compact: true,
          eyebrow: [
            ?detail.obj('meeting')?.str('meeting_name'),
            ?session.str('session_name'),
            sessionWhen(session.str('date_start')),
          ].join(' · '),
          title: title,
          accent: accent,
          lede: lede,
          actions: [
            if (detail.flag('detail_available'))
              NxButton(
                'Watch the replay',
                icon: LucideIcons.play,
                onPressed: () => context.push('/f1/sessions/${widget.sessionKey}/replay'),
              ),
          ],
        ),
        F1LockoutBanner(health: health),
        if (podium.isNotEmpty)
          NxBento(
            children: [
              for (final (i, r) in podium.indexed)
                NxField(
                  bg: colourOf(r.integer('driver_number') ?? 0),
                  span: i == 0 ? 2 : 1,
                  label: [
                    'P${r.integer('position')}',
                    ?drivers[r.integer('driver_number')]?.str('team_name'),
                  ].join(' · '),
                  aside: i == 0 ? timing(r['duration']) : timing(r['gap_to_leader'], gap: true),
                  value: acronym(r.integer('driver_number') ?? 0),
                  valueSize: i == 0 ? 56 : 40,
                  sub: fullName(r.integer('driver_number') ?? 0),
                ),
            ],
          ),
        if (!detail.flag('detail_synced'))
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: NxEmptyState(icon: LucideIcons.clock, title: 'No timing data yet', body: lede),
          )
        else ...[
          const SizedBox(height: 26),
          NxPillNav<_Tab>(
            items: tabs,
            value: tab,
            onChanged: (t) => setState(() {
              _tab = t;
              _limit = _pageSize;
            }),
          ),
          const SizedBox(height: 16),
          table,
        ],
        const NxSectionHeader('Session'),
        NxPanel(
          child: NxFacts(columns: 2, [
            ('Type', session.str('session_type')),
            ('Starts', sessionWhen(session.str('date_start'))),
            ('Pit stops', pits.isEmpty ? null : '${pits.length}'),
            ('Overtakes', analysis.list('overtakes').isEmpty ? null : '${analysis.list('overtakes').length}'),
          ]),
        ),
        if (weather.isNotEmpty) ...[
          const NxSectionHeader('Conditions'),
          NxPanel(
            child: NxFacts(columns: 2, [
              ('Air', weatherRange(weather, 'air_temperature', '°C')),
              ('Track', weatherRange(weather, 'track_temperature', '°C')),
              ('Humidity', weatherRange(weather, 'humidity', '%')),
              ('Wind', weatherRange(weather, 'wind_speed', ' m/s')),
              ('Rain', weather.any((w) => w.flag('rainfall')) ? 'Yes' : 'Dry'),
            ]),
          ),
        ],
      ],
    );
  }
}

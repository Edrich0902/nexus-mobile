import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/f1/f1.dart';
import 'package:nexus_mobile/features/f1/f1_widgets.dart';

/// Web F1MeetingView: a race weekend with its timeline, sessions and facts.
class F1MeetingScreen extends ConsumerWidget {
  const F1MeetingScreen({required this.meetingKey, super.key});

  final int meetingKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(f1MeetingProvider(meetingKey));
    final now = ref.watch(f1ClockProvider).value ?? DateTime.now();
    final health = ref.watch(f1StatusProvider).value?.obj('provider_health');
    final season = ref.watch(f1SeasonProvider).value?.season;

    return NxPage(
      onRefresh: () async {
        ref.invalidate(f1MeetingProvider(meetingKey));
        await ref.read(f1MeetingProvider(meetingKey).future);
      },
      children: [
        NxAsync(
          value: async,
          onRetry: () => ref.invalidate(f1MeetingProvider(meetingKey)),
          data: (m) {
            final c = context.nx;
            final sessions = m.list('sessions');
            final list = rounds(season?.list('meetings') ?? const []);
            final i = list.indexWhere((r) => r.integer('meeting_key') == meetingKey);
            final phase = meetingState(m, now);
            final focus = focusSession(sessions, now);
            final (title, accent) = splitMeetingName(m.text('meeting_name'));
            final cd = focus == null ? null : countdown(focus.str('date_start'), now);

            final eyebrow = [
              if (i >= 0) 'Round ${i + 1} of ${list.length}',
              ?m.str('country_name'),
              if (phase != SessionState.done && focus != null)
                cd == null
                    ? '${focus.text('session_name')} live'
                    : '${focus.text('session_name')} in ${cd.$1.replaceAll(RegExp(r',$'), '')}',
            ].join(' · ');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NxStage(
                  live: phase == SessionState.live,
                  eyebrow: eyebrow,
                  title: title,
                  accent: accent,
                  lede: '${meetingPlace(m)} · ${meetingDates(m)}',
                  visual: F1Circuit(url: m.str('circuit_image')),
                ),
                F1LockoutBanner(health: health),
                if (sessions.isNotEmpty) ...[
                  const NxSectionHeader('The weekend · your time'),
                  F1Weekend(sessions: sessions, now: now),
                ],
                const NxSectionHeader('Sessions'),
                if (sessions.isEmpty)
                  Text('No sessions published for this weekend yet.', style: NxText.muted(context))
                else
                  for (final (idx, s) in sessions.indexed) _SessionRow(session: s, now: now, first: idx == 0),
                const NxSectionHeader('About the weekend'),
                NxPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NxFacts(columns: 2, [
                        ('Circuit', m.str('circuit_short_name')),
                        ('Location', m.str('location')),
                        ('Country', m.str('country_name')),
                        ('Dates', meetingDates(m)),
                        ('Layout', m.str('circuit_type')),
                        (
                          'Local offset',
                          switch (m.str('gmt_offset')) {
                            final o? => 'UTC ${o.length > 6 ? o.substring(0, 6) : o}',
                            null => null,
                          },
                        ),
                      ]),
                      if (m.str('meeting_official_name') case final official?)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(official, style: NxText.sans(size: 12.5, color: c.ink3, height: 1.45)),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.now, required this.first});

  final Json session;
  final DateTime now;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final (label, tone) = sessionStatus(session, now);
    final toneColour = switch (tone) {
      StatusTone.ok => NexusColors.ok,
      StatusTone.live => c.acc,
      StatusTone.pending => NexusColors.warn,
      StatusTone.muted => c.ink3,
    };
    return InkWell(
      onTap: () => context.push('/f1/sessions/${session.integer('session_key')}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.text('session_name'),
                    style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                  ),
                  Text(
                    [?session.str('session_type'), sessionWhen(session.str('date_start'))].join(' · '),
                    style: NxText.sans(size: 12.5, color: c.ink3),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tone == StatusTone.live) ...[NxLiveDot(color: toneColour, size: 6), const SizedBox(width: 6)],
                Text(
                  label,
                  style: NxText.sans(size: 12.5, weight: FontWeight.w600, color: toneColour),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 16, color: c.ink3),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/native/open_external.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';

// ── Helpers (web routes/admin/admin.ts) ───────────────────────────────────

String formatUptime(num? seconds) {
  if (seconds == null) return '—';
  final s = seconds.toInt();
  final (d, h, m) = (s ~/ 86400, (s % 86400) ~/ 3600, (s % 3600) ~/ 60);
  return d > 0 ? '${d}d ${h}h' : '${h}h ${m}m';
}

num? memoryUsed(Json? server) {
  final mem = server?.obj('memory');
  if (mem == null) return null;
  if (mem.number('system_used_bytes') case final used?) return used;
  final (total, available) = (mem.number('system_total_bytes'), mem.number('system_available_bytes'));
  if (total != null && available != null) return math.max(0, total - available);
  return mem.number('php_usage_bytes');
}

num? diskUsed(Json? server) {
  final disk = server?.obj('disk');
  if (disk == null) return null;
  if (disk.number('used_bytes') case final used?) return used;
  final (total, free) = (disk.number('total_bytes'), disk.number('free_bytes'));
  return total != null && free != null ? math.max(0, total - free) : null;
}

String shortClass(String name) => name.split(r'\').last;

double? share(num? percent) => percent == null || percent.isNaN ? null : (percent / 100).clamp(0, 1).toDouble();

Color statusTone(BuildContext context, String? status) => switch ((status ?? '').toLowerCase()) {
  'processed' || 'success' || 'ok' => NexusColors.ok,
  'failed' || 'failure' => NexusColors.bad,
  'pending' || 'queued' || 'released' => NexusColors.warn,
  'processing' || 'reserved' => context.nx.acc,
  _ => context.nx.ink3,
};

// ── Data ───────────────────────────────────────────────────────────────────

final adminOverviewProvider = FutureProvider.autoDispose<Json>(
  (ref) async => asJson(await ref.watch(apiClientProvider).get('/admin/overview')),
);

final adminRecentJobsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) async => asJsonList(await ref.watch(apiClientProvider).get('/admin/recent-jobs')),
);

/// Web AdminView: server health, queue depth, pending / failed jobs and
/// recent Telescope activity. Polls the overview every 12 seconds.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  Timer? _poll;
  String? _queue;
  String? _busy;

  PageQuery get _jobs => PageQuery('/admin/jobs', {'queue': _queue, 'per_page': 25});
  static final _failed = PageQuery('/admin/failed-jobs', const {'per_page': 25});

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => ref.invalidate(adminOverviewProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _refreshAll() => ref
    ..invalidate(adminOverviewProvider)
    ..invalidate(adminRecentJobsProvider)
    ..invalidate(pagedProvider(_jobs))
    ..invalidate(pagedProvider(_failed));

  Future<void> _failedAction(String uuid, {required bool retry}) async {
    if (!retry && !await showNxConfirm(context, message: 'Forget this failed job?', confirmLabel: 'Forget')) return;
    setState(() => _busy = uuid);
    try {
      final api = ref.read(apiClientProvider);
      retry ? await api.post('/admin/failed-jobs/$uuid/retry') : await api.delete('/admin/failed-jobs/$uuid');
      _refreshAll();
      if (mounted) showNxToast(context, retry ? 'Job queued for retry.' : 'Job forgotten.');
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminOverviewProvider);
    final o = overviewAsync.value;

    return NxPage(
      onRefresh: () async {
        _refreshAll();
        await ref.read(adminOverviewProvider.future);
      },
      children: [
        if (o == null)
          overviewAsync.hasError
              ? NxErrorState(error: overviewAsync.error!, onRetry: _refreshAll)
              : const NxPageSkeleton()
        else
          _body(context, o, refreshing: overviewAsync.isRefreshing),
      ],
    );
  }

  Widget _body(BuildContext context, Json o, {required bool refreshing}) {
    final c = context.nx;
    final server = o.obj('server');
    final queues = o.list('queues');
    final failed = o.integer('failed_job_count') ?? 0;
    final openf1 = o.obj('providers')?.obj('openf1');
    final (pending, reserved, delayed) = queues.fold<(int, int, int)>(
      (0, 0, 0),
      (t, q) =>
          (t.$1 + (q.integer('pending') ?? 0), t.$2 + (q.integer('reserved') ?? 0), t.$3 + (q.integer('delayed') ?? 0)),
    );

    final (title, accent) = failed > 0
        ? ('$failed failed', failed == 1 ? 'job' : 'jobs')
        : pending > 0
        ? ('$pending jobs', 'queued')
        : ('All', 'quiet');

    final eyebrow = [
      'Operations',
      ?server?.str('laravel_env'),
      if (o.date('sampled_at') case final at?) 'sampled ${relativeTime(at)}',
    ].join(' · ');

    final lede = server == null
        ? 'Queues, failures and container health.'
        : 'Up ${formatUptime(server.number('uptime_seconds'))} on PHP ${server.text('php_version')} with the '
              '${server.text('queue_connection')} queue. Refreshes every 12 seconds while this page is open.';

    final memory = server?.obj('memory');
    final disk = server?.obj('disk');
    final load = server?['load'] is List ? (server!['load'] as List).whereType<num>().toList() : null;
    final memSource = memory?.str('source') == 'cgroup' ? 'container' : (memory?.str('source') ?? 'php');

    final maxPending = queues.fold<int>(1, (m, q) => math.max(m, q.integer('pending') ?? 0));
    final slices = [
      ('Waiting', math.max(0, pending - reserved), c.acc),
      ('Running', reserved, NexusColors.ok),
      ('Delayed', delayed, NexusColors.warn),
      ('Failed', failed, NexusColors.bad),
    ];
    final sliceSum = slices.fold<int>(0, (a, s) => a + s.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxStage(
          compact: true,
          live: true,
          eyebrow: eyebrow,
          title: title,
          accent: accent,
          lede: lede,
          actions: [
            NxButton(
              'Refresh',
              icon: LucideIcons.refreshCw,
              variant: NxButtonVariant.secondary,
              loading: refreshing,
              onPressed: _refreshAll,
            ),
            if (o.str('telescope_url') case final url?)
              NxIconButton(LucideIcons.externalLink, tooltip: 'Telescope', onPressed: () => openExternal(url)),
          ],
        ),
        if (server != null)
          CollectionFields(
            section: SectionKey.admin,
            fields: [
              CollectionField(
                key: 'memory',
                label: 'Memory',
                aside: memory?.number('system_used_percent') == null
                    ? null
                    : '${memory!.number('system_used_percent')!.round()}%',
                value: formatBytes(memoryUsed(server)),
                sub: memory?.number('system_total_bytes') == null
                    ? memSource
                    : 'of ${formatBytes(memory!.number('system_total_bytes'))} · $memSource',
                progress: share(memory?.number('system_used_percent')),
              ),
              CollectionField(
                key: 'cpu',
                label: 'CPU',
                value: server.number('cpu_percent') != null
                    ? '${server.number('cpu_percent')!.round()}%'
                    : (load?.firstOrNull?.toStringAsFixed(2) ?? '—'),
                sub: load == null ? null : 'load ${load.map((n) => n.toStringAsFixed(2)).join(' · ')}',
                progress: share(server.number('cpu_percent')),
                variant: FieldVariant.tint,
              ),
              CollectionField(
                key: 'disk',
                label: 'Disk',
                aside: disk?.number('used_percent') == null ? null : '${disk!.number('used_percent')!.round()}%',
                value: formatBytes(diskUsed(server)),
                sub: '${formatBytes(disk?.number('free_bytes'))} free on ${disk?.str('path') ?? '/'}',
                progress: share(disk?.number('used_percent')),
                variant: FieldVariant.tint,
              ),
              CollectionField(
                key: 'queue',
                label: 'Queue',
                value: '$pending',
                sub: '$reserved running · $delayed delayed · $failed failed',
                variant: FieldVariant.outline,
              ),
            ],
          ),
        if (openf1?.flag('live_lockout') ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: NexusColors.warn.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(NxRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 16, color: NexusColors.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'OpenF1 live lockout — ${openf1?.str('reason') ?? 'the free API is restricted during a live session.'}',
                      style: NxText.sans(size: 13.5, color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const NxSectionHeader('Pending by queue'),
        if (queues.isEmpty || pending == 0)
          Text('No pending jobs — every queue is clear.', style: NxText.muted(context))
        else
          NxMeters(labelWidth: 96, showWords: true, [
            for (final q in queues)
              ProfileAxis(q.text('queue'), (q.integer('pending') ?? 0) / maxPending, '${q.integer('pending') ?? 0}'),
          ]),
        const NxSectionHeader('Queue health'),
        if (sliceSum == 0)
          Text('Nothing queued or failed right now.', style: NxText.muted(context))
        else ...[
          Semantics(
            label: slices.map((s) => '${s.$2} ${s.$1.toLowerCase()}').join(', '),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final s in slices)
                      if (s.$2 > 0)
                        Expanded(
                          flex: s.$2,
                          child: ColoredBox(color: s.$3),
                        ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final s in slices)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(s.$1, style: NxText.sans(size: 13, color: c.ink2)),
                    const SizedBox(width: 6),
                    Text(
                      '${s.$2}',
                      style: NxText.sans(size: 13, weight: FontWeight.w700, color: c.ink),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const NxSectionHeader('Pending jobs'),
        NxPillNav<String?>(
          items: [
            (null, 'All queues'),
            for (final q in queues) (q.str('queue'), '${q.text('queue')} (${q.integer('pending') ?? 0})'),
          ],
          value: _queue,
          onChanged: (q) => setState(() => _queue = q),
        ),
        const SizedBox(height: 8),
        _PagedJobs(
          query: _jobs,
          empty: 'No pending jobs in this queue.',
          row: (j) => _JobRow(
            title: shortClass(j.text('job_class')),
            chips: [j.text('queue'), 'attempt ${j.integer('attempts') ?? 0}'],
            trailing: formatDateTime(j.date('available_at')),
          ),
        ),
        _FailedHeader(query: _failed),
        _PagedJobs(
          query: _failed,
          empty: 'No failed jobs — looking healthy.',
          row: (j) => _JobRow(
            title: shortClass(j.text('job_class')),
            chips: [j.text('queue'), relativeTime(j.date('failed_at'))],
            detail: j.str('exception_summary'),
            actions: [
              NxIconButton(
                LucideIcons.refreshCw,
                tooltip: 'Retry job',
                size: 34,
                onPressed: _busy != null ? null : () => _failedAction(j.text('uuid'), retry: true),
              ),
              NxIconButton(
                LucideIcons.trash2,
                tooltip: 'Forget job',
                size: 34,
                onPressed: _busy != null ? null : () => _failedAction(j.text('uuid'), retry: false),
              ),
            ],
          ),
        ),
        const NxSectionHeader('Recent activity · Telescope'),
        NxAsync(
          value: ref.watch(adminRecentJobsProvider),
          onRetry: () => ref.invalidate(adminRecentJobsProvider),
          loading: const NxSkeleton(height: 160, radius: NxRadius.md),
          data: (jobs) => jobs.isEmpty
              ? Text('No Telescope job entries yet.', style: NxText.muted(context))
              : Column(
                  children: [
                    for (final j in jobs)
                      _JobRow(
                        title: shortClass(j.text('job_class')),
                        chips: [?j.str('queue')],
                        status: j.str('status') ?? 'unknown',
                        trailing: relativeTime(j.date('created_at')),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _FailedHeader extends ConsumerWidget {
  const _FailedHeader({required this.query});

  final PageQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      NxSectionHeader('Failed jobs · ${ref.watch(pagedProvider(query)).value?.total ?? 0}');
}

class _PagedJobs extends ConsumerWidget {
  const _PagedJobs({required this.query, required this.empty, required this.row});

  final PageQuery query;
  final String empty;
  final Widget Function(Json) row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(pagedProvider(query));
    final s = list.value;
    if (s == null) {
      return list.hasError
          ? NxErrorState(error: list.error!, compact: true, onRetry: () => ref.invalidate(pagedProvider(query)))
          : const NxSkeleton(height: 140, radius: NxRadius.md);
    }
    if (s.items.isEmpty) return Text(empty, style: NxText.muted(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final j in s.items) row(j),
        if (s.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: NxButton(
              'Show more · ${s.remaining} left',
              variant: NxButtonVariant.ghost,
              loading: s.loadingMore,
              onPressed: () => unawaited(
                ref.read(pagedProvider(query).notifier).loadMore().catchError((Object e) {
                  if (context.mounted) showApiError(context, e);
                }),
              ),
            ),
          ),
      ],
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.title,
    this.chips = const [],
    this.detail,
    this.trailing,
    this.status,
    this.actions = const [],
  });

  final String title;
  final List<String> chips;
  final String? detail;
  final String? trailing;
  final String? status;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NxText.mono(size: 12.5, weight: FontWeight.w600, color: c.ink),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final chip in chips.where((s) => s.isNotEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: c.tint2, borderRadius: BorderRadius.circular(NxRadius.pill)),
                        child: Text(chip, style: NxText.sans(size: 11.5, color: c.ink2)),
                      ),
                    if (status != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusTone(context, status).withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(NxRadius.pill),
                        ),
                        child: Text(
                          status!,
                          style: NxText.sans(size: 11.5, weight: FontWeight.w600, color: statusTone(context, status)),
                        ),
                      ),
                  ],
                ),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      detail!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: NxText.sans(size: 12.5, color: NexusColors.bad, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(trailing!, style: NxText.sans(size: 12, color: c.ink3)),
            ),
          ...actions,
        ],
      ),
    );
  }
}

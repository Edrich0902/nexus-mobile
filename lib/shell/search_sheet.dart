import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/home/hub_api.dart';

class CommandItem {
  const new({
    required this.id,
    required this.label,
    required this.group,
    required this.icon,
    required this.path,
    this.hint,
    this.color,
    this.meta,
    this.keywords = const [],
  });

  final String id;
  final String label;
  final String group;
  final IconData icon;
  final String path;
  final String? hint;
  final Color? color;
  final String? meta;
  final List<String> keywords;
}

/// 3 prefix, 2 word-prefix, 1 substring, 0 none (web command.store).
int matchScore(String text, String query) {
  final t = text.toLowerCase();
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 1;
  if (t.startsWith(q)) return 3;
  if (t.split(RegExp(r'[\s\-–·&]+')).any((w) => w.startsWith(q))) return 2;
  return t.contains(q) ? 1 : 0;
}

int scoreItem(CommandItem item, String query) {
  final label = matchScore(item.label, query) * 3;
  final kw = item.keywords.isEmpty
      ? 0
      : item.keywords.map((k) => matchScore(k, query)).reduce((a, b) => a > b ? a : b) * 2;
  final hint = item.hint == null ? 0 : matchScore(item.hint!, query);
  return [label, kw, hint].reduce((a, b) => a > b ? a : b);
}

const List<(String, String, String, SectionKey, List<String>)> _captureActions = [
  ('wine', 'Log a wine from a photo', 'Opens the camera · reads the label', SectionKey.cellar, ['cellar', 'bottle']),
  ('beer', 'Log a beer from a photo', 'Can, bottle or tap list', SectionKey.beer, ['can', 'brewery']),
  ('spirit', 'Log a spirit from a photo', 'Reads the bottle label', SectionKey.spirits, ['whisky', 'gin', 'rum']),
  ('book', 'Add a book', 'Scan the barcode or cover', SectionKey.library, ['isbn', 'barcode', 'library']),
];

List<CommandItem> _syncItems(String query) {
  final actions = [
    for (final (kind, label, hint, section, keywords) in _captureActions)
      CommandItem(
        id: 'capture:$kind',
        label: label,
        hint: hint,
        group: 'Actions',
        icon: LucideIcons.camera,
        color: section.field.bg,
        path: kind == 'book' ? '/capture?kind=book&mode=barcode' : '/capture?kind=$kind',
        keywords: ['capture', 'camera', 'scan', kind, ...keywords],
      ),
  ];
  CommandItem nav(Destination d) => CommandItem(
    id: 'go:${d.key}',
    label: d.label,
    group: 'Go to',
    icon: d.icon,
    color: d.section.field.bg,
    meta: d.section.label == d.label ? null : d.section.label,
    keywords: d.keywords,
    path: d.to,
  );
  if (query.trim().isEmpty) {
    return [
      ...actions.take(2),
      ...[...Nav.primary, ...Nav.secondary].map(nav),
    ];
  }
  final ranked = [...actions, ...Nav.all.map(nav)].map((i) => (i, scoreItem(i, query))).where((r) => r.$2 > 0).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return ranked.take(12).map((r) => r.$1).toList();
}

IconData _searchIcon(String? type) => switch (type) {
  'cellar_wine' => LucideIcons.wine,
  'beer_beer' => LucideIcons.beer,
  'spirit_spirit' => LucideIcons.glassWater,
  'kitchen_recipe' => LucideIcons.chefHat,
  'library_book' => LucideIcons.bookOpen,
  'github_repo' => LucideIcons.codeXml,
  'spotify_playlist' => LucideIcons.audioLines,
  _ => LucideIcons.search,
};

Color? _searchColour(String path) => Nav.sectionFor(path).field.bg;

/// Search (web ⌘K palette) as a full-height sheet.
Future<void> showSearchSheet(BuildContext context, {String initial = ''}) =>
    showNxSheet<void>(context, expand: true, builder: (_) => _SearchBody(initial: initial));

class _SearchBody extends ConsumerStatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  ConsumerState<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends ConsumerState<_SearchBody> {
  late final _q = TextEditingController(text: widget.initial);
  Timer? _debounce;
  CancelToken? _cancel;
  List<CommandItem> _remote = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) _search(widget.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancel?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() {});
    _debounce?.cancel();
    _cancel?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _remote = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      final token = _cancel = CancelToken();
      try {
        final groups = await ref.read(hubApiProvider).search(q.trim(), cancel: token);
        if (token.isCancelled || !mounted) return;
        setState(() {
          _remote = [
            for (final g in groups)
              for (final item in g.list('items'))
                if (searchItemPath(item) case final path?)
                  CommandItem(
                    id: 'search:${item.str('type')}:${item.str('id')}',
                    label: item.text('title'),
                    hint: item.str('subtitle'),
                    group: 'In your collections',
                    icon: _searchIcon(item.str('type')),
                    color: _searchColour(path),
                    meta: g.str('label'),
                    path: path,
                  ),
          ];
          _loading = false;
        });
      } on Object {
        if (mounted && !token.isCancelled) setState(() => _loading = false);
      }
    });
  }

  void _run(CommandItem item) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (item.path.startsWith('/capture')) {
      router.push(item.path);
    } else {
      router.go(item.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final query = _q.text;
    final items = [..._syncItems(query), ..._remote];
    final groups = <String, List<CommandItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.group, () => []).add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxSearchField(
          controller: _q,
          hint: 'Search Nexus',
          autofocus: true,
          onChanged: _search,
          onSubmitted: (_) {
            if (items.isNotEmpty) _run(items.first);
          },
          trailing: _loading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.acc),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? NxEmptyState(icon: LucideIcons.search, title: 'Nothing matches “$query”', compact: true)
              : ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    for (final e in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                        child: Text(e.key, style: NxText.label(context)),
                      ),
                      for (final i in e.value) _Row(item: i, query: query, onTap: () => _run(i)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const new({required this.item, required this.query, required this.onTap});

  final CommandItem item;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final bg = item.color ?? c.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NxRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, size: 18, color: inkFor(bg)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Highlight(text: item.label, query: query),
                  if (item.hint != null)
                    Text(
                      item.hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NxText.sans(size: 12.5, color: c.ink3),
                    ),
                ],
              ),
            ),
            if (item.meta != null) Text(item.meta!, style: NxText.sans(size: 12, color: c.ink4)),
          ],
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const new({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final base = NxText.sans(size: 15, weight: FontWeight.w500, color: c.ink);
    final q = query.trim();
    final idx = q.isEmpty ? -1 : text.toLowerCase().indexOf(q.toLowerCase());
    if (idx < 0) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + q.length),
            style: TextStyle(color: c.acc, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}

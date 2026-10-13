import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/library/library_api.dart';
import 'package:nexus_mobile/features/library/library_helpers.dart';

/// Open Library results as pickable rows with a small cover (web
/// BookCandidates).
class BookCandidates extends StatelessWidget {
  const new({required this.items, required this.onPick, super.key});

  final List<Json> items;
  final ValueChanged<Json> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Column(
      children: [
        for (final r in items)
          NxPressable(
            onTap: () => onPick(r),
            scale: .985,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 54,
                    child: NxImage(url: r.str('cover_url'), radius: 4, fallbackIcon: LucideIcons.bookOpen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.text('title', 'Untitled'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NxText.sans(size: 14.5, weight: FontWeight.w600, color: c.ink),
                        ),
                        Text(
                          [
                            r.strings('authors').join(', '),
                            r.integer('publish_year')?.toString(),
                          ].where((s) => s != null && s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NxText.sans(size: 13, color: c.ink3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Add a book from Open Library or by hand (web LibraryView dialog).
Future<Json?> showAddBookSheet(BuildContext context, {String? initialQuery}) => showNxSheet<Json>(
  context,
  title: 'Add a book',
  expand: true,
  builder: (_) => _AddBook(initialQuery: initialQuery),
);

class _AddBook extends ConsumerStatefulWidget {
  const new({this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<_AddBook> createState() => _AddBookState();
}

class _AddBookState extends ConsumerState<_AddBook> {
  String _mode = 'catalog';
  late final _query = TextEditingController(text: widget.initialQuery);
  final _title = TextEditingController();
  final _authors = TextEditingController();
  final _isbn = TextEditingController();
  final _notes = TextEditingController();
  String _status = 'want';
  double? _rating;
  List<Json> _results = const [];
  bool _searching = false;
  bool _saving = false;
  CancelToken? _cancel;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    if (widget.initialQuery?.isNotEmpty ?? false) unawaited(_search());
  }

  @override
  void dispose() {
    _cancel?.cancel();
    for (final c in [_query, _title, _authors, _isbn, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Json get _extra => {
    'status': _status,
    'rating': _rating,
    'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
  };

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    setState(() => _searching = true);
    try {
      final r = await ref.read(libraryApiProvider).searchCatalog(q, cancel: token);
      if (mounted) setState(() => _results = r);
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e) && mounted) showApiError(context, e);
    } finally {
      if (mounted && identical(token, _cancel)) setState(() => _searching = false);
    }
  }

  Future<void> _save(Future<Json> Function() task) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final book = await task();
      if (mounted) Navigator.of(context).pop(book);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not add the book.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pick(Json r) => _save(() => ref.read(libraryApiProvider).createFromCatalog(r.text('ol_work_key'), _extra));

  void _manual() {
    if (_title.text.trim().isEmpty) return;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    _save(
      () => ref.read(libraryApiProvider).create({
        'title': _title.text.trim(),
        'authors': t(_authors),
        'isbn': t(_isbn),
        ..._extra,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final common = [
      NxFormRow(
        children: [
          NxPickerField<String>(
            label: 'Status',
            options: bookStatuses,
            value: _status,
            clearable: false,
            onChanged: (v) => setState(() => _status = v ?? 'want'),
          ),
          NxFormSlot(
            label: 'Rating',
            child: NxRatingInput(value: _rating, size: 26, onChanged: (v) => setState(() => _rating = v)),
          ),
        ],
      ),
      NxTextField(label: 'Notes', controller: _notes, maxLines: 2),
    ];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: NxForm(
              children: [
                NxPillNav<String>(
                  items: const [('catalog', 'Open Library'), ('manual', 'By hand')],
                  value: _mode,
                  onChanged: (v) => setState(() => _mode = v),
                ),
                if (_mode == 'catalog') ...[
                  NxSearchField(
                    controller: _query,
                    hint: 'Title, author or ISBN',
                    autofocus: widget.initialQuery == null,
                    onSubmitted: (_) => _search(),
                    trailing: _searching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : NxIconButton(LucideIcons.arrowRight, tooltip: 'Search', size: 34, onPressed: _search),
                  ),
                  ...common,
                  if (_results.isNotEmpty)
                    AbsorbPointer(
                      absorbing: _saving,
                      child: BookCandidates(items: _results, onPick: _pick),
                    )
                  else
                    Text('Pick a result to add it with its cover and details.', style: NxText.muted(context)),
                ] else ...[
                  NxTextField(label: 'Title', controller: _title, autofocus: true),
                  NxFormRow(
                    children: [
                      NxTextField(label: 'Authors', controller: _authors),
                      NxTextField(label: 'ISBN', controller: _isbn, keyboardType: TextInputType.number),
                    ],
                  ),
                  ...common,
                ],
              ],
            ),
          ),
        ),
        if (_mode == 'manual')
          NxSheetActions(label: 'Add book', busy: _saving, onSubmit: _title.text.trim().isEmpty ? null : _manual),
      ],
    );
  }
}

/// Edit a book's details, status and dates (web LibraryBookView dialog).
Future<void> showEditBookSheet(BuildContext context, Json book) => showNxSheet<void>(
  context,
  title: 'Edit book',
  expand: true,
  builder: (_) => _EditBook(book: book),
);

class _EditBook extends ConsumerStatefulWidget {
  const new({required this.book});

  final Json book;

  @override
  ConsumerState<_EditBook> createState() => _EditBookState();
}

class _EditBookState extends ConsumerState<_EditBook> {
  late final _title = TextEditingController(text: widget.book.str('title'));
  late final _authors = TextEditingController(text: widget.book.str('authors'));
  late final _isbn = TextEditingController(text: widget.book.str('isbn'));
  late final _notes = TextEditingController(text: widget.book.str('notes'));
  late String _status = widget.book.str('status') ?? 'want';
  late double? _rating = widget.book.number('rating');
  late DateTime? _started = parseDay(widget.book.str('started_at'));
  late DateTime? _finished = parseDay(widget.book.str('finished_at'));
  bool _saving = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_title, _authors, _isbn, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(libraryApiProvider).update(widget.book.integer('id') ?? 0, {
        'title': _title.text.trim(),
        'authors': t(_authors),
        'isbn': t(_isbn),
        'status': _status,
        'rating': _rating,
        'notes': t(_notes),
        'started_at': isoDay(_started),
        'finished_at': isoDay(_finished),
      });
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e, 'Could not save.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: NxForm(
              children: [
                NxTextField(label: 'Title', controller: _title, error: _error?.field('title')),
                NxFormRow(
                  children: [
                    NxTextField(label: 'Authors', controller: _authors),
                    NxTextField(label: 'ISBN', controller: _isbn, error: _error?.field('isbn')),
                  ],
                ),
                NxFormRow(
                  children: [
                    NxPickerField<String>(
                      label: 'Status',
                      options: bookStatuses,
                      value: _status,
                      clearable: false,
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                    NxFormSlot(
                      label: 'Rating',
                      child: NxRatingInput(value: _rating, size: 26, onChanged: (v) => setState(() => _rating = v)),
                    ),
                  ],
                ),
                NxFormRow(
                  children: [
                    NxDateField(label: 'Started', value: _started, onChanged: (d) => setState(() => _started = d)),
                    NxDateField(label: 'Finished', value: _finished, onChanged: (d) => setState(() => _finished = d)),
                  ],
                ),
                if (_error?.field('finished_at') case final e?)
                  Text(e, style: NxText.sans(size: 13, color: NexusColors.bad)),
                NxTextField(label: 'Notes', controller: _notes, maxLines: 4),
                if (_error != null && _error!.fieldErrors.isEmpty)
                  Text(_error!.message, style: NxText.sans(size: 13.5, color: NexusColors.bad)),
              ],
            ),
          ),
        ),
        NxSheetActions(label: 'Save', busy: _saving, onSubmit: _title.text.trim().isEmpty ? null : _save),
      ],
    );
  }
}

/// Match a book to an Open Library work (web LibraryMatchDialog).
Future<void> showMatchBookSheet(BuildContext context, int bookId) => showNxSheet<void>(
  context,
  title: 'Match in Open Library',
  expand: true,
  builder: (_) => _MatchBook(bookId: bookId),
);

class _MatchBook extends ConsumerStatefulWidget {
  const new({required this.bookId});

  final int bookId;

  @override
  ConsumerState<_MatchBook> createState() => _MatchBookState();
}

class _MatchBookState extends ConsumerState<_MatchBook> {
  final _query = TextEditingController();
  Json? _result;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final q = _query.text.trim();
      final r = await ref.read(libraryApiProvider).candidates(widget.bookId, q: q.isEmpty ? null : q);
      if (mounted) setState(() => _result = r);
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _do(Future<Object?> Function() task) async {
    setState(() => _saving = true);
    try {
      await task();
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(libraryApiProvider);
    final candidates = _result?.list('candidates') ?? const [];
    return Column(
      children: [
        NxSearchField(
          controller: _query,
          hint: 'Title, author or ISBN',
          onSubmitted: (_) => _fetch(),
          trailing: NxIconButton(LucideIcons.arrowRight, tooltip: 'Search', size: 34, onPressed: _fetch),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Column(
                  children: [
                    NxSkeleton(height: 54),
                    SizedBox(height: 10),
                    NxSkeleton(height: 54),
                    SizedBox(height: 10),
                    NxSkeleton(height: 54),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (candidates.isNotEmpty)
                        AbsorbPointer(
                          absorbing: _saving,
                          child: BookCandidates(
                            items: candidates,
                            onPick: (c) => _do(() => api.match(widget.bookId, c.text('ol_work_key'))),
                          ),
                        )
                      else if (_result != null)
                        Text(
                          _result!.str('message') ?? 'No matches found. Try the author or ISBN.',
                          style: NxText.muted(context),
                        ),
                      if (_result?.flag('from_cache') ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text('Showing cached results.', style: NxText.muted(context, size: 12)),
                        ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              NxButton(
                'It is not listed',
                variant: NxButtonVariant.ghost,
                onPressed: _saving ? null : () => _do(() => api.noMatch(widget.bookId)),
              ),
              const Spacer(),
              NxButton('Close', variant: NxButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ],
    );
  }
}

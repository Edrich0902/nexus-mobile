import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/collections/collection_index.dart';
import 'package:nexus_mobile/features/collections/drink_detail.dart' show ArtAmbient;
import 'package:nexus_mobile/features/collections/prints.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/library/book_sheets.dart';
import 'package:nexus_mobile/features/library/library_api.dart';
import 'package:nexus_mobile/features/library/library_helpers.dart';

/// Library index (web LibraryView): the book you're reading on the stage,
/// shelf counts, a status filter and the shelf as prints.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with DebouncedSearch {
  String _status = 'all';
  bool _finishing = false;

  PageQuery get _query => bookQuery(q: searched, status: _status == 'all' ? null : _status);

  Future<void> _add() async {
    final book = await showAddBookSheet(context);
    final id = book?.integer('id');
    if (id != null && mounted) unawaited(context.push('/library/books/$id'));
  }

  Future<void> _finish(Json book) async {
    setState(() => _finishing = true);
    try {
      await ref.read(libraryApiProvider).advance(book);
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pulse = ref.watch(libraryPulseProvider).value;
    final reading = pulse?.list('reading') ?? const [];
    final current = reading.firstOrNull;
    final counts = pulse?.obj('counts');

    final page = NxPage(
      onRefresh: () async {
        ref
          ..invalidate(libraryPulseProvider)
          ..invalidate(pagedProvider(_query));
        await ref.read(pagedProvider(_query).future);
      },
      children: [
        if (current != null)
          _ReadingStage(book: current, finishing: _finishing, onFinish: () => _finish(current), onAdd: _add)
        else
          NxStage(
            compact: true,
            eyebrow: 'Library',
            title: 'Your',
            accent: 'shelf',
            lede: 'Books you own, are reading or want to read — matched to Open Library for covers and details.',
            actions: [NxButton('Add a book', icon: LucideIcons.plus, onPressed: _add)],
          ),
        if (pulse != null && pulse.isNotEmpty)
          CollectionFields(
            section: SectionKey.library,
            fields: [
              CollectionField(key: 'total', label: 'On the shelf', value: '${counts?.integer('total') ?? 0}'),
              CollectionField(
                key: 'read',
                label: 'Read',
                value: '${counts?.integer('read') ?? 0}',
                variant: FieldVariant.tint,
              ),
              if (current != null)
                CollectionField(
                  key: 'reading',
                  label: 'Reading now',
                  aside: reading.length > 1 ? '+${reading.length - 1} more' : null,
                  title: current.text('title'),
                  variant: FieldVariant.tint,
                  span: 2,
                  to: '/library/books/${current.integer('id')}',
                )
              else
                const CollectionField(
                  key: 'reading',
                  label: 'Reading now',
                  title: 'Pick your next book',
                  variant: FieldVariant.outline,
                  span: 2,
                ),
              CollectionField(
                key: 'want',
                label: 'Want to read',
                value: '${counts?.integer('want') ?? 0}',
                variant: FieldVariant.outline,
                span: 2,
              ),
            ],
          ),
        const SizedBox(height: 22),
        NxPillNav<String>(
          items: const [('all', 'All'), ...bookStatuses],
          value: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: 12),
        NxSearchField(
          controller: searchController,
          hint: 'Search title or author…',
          onChanged: onSearchChanged,
          onSubmitted: submitSearch,
        ),
        PagedPrints(
          query: _query,
          toPrint: bookPrint,
          filterLabel: 'Author',
          empty: NxEmptyState(
            title: 'No books yet',
            body: 'Search Open Library to add a book with its cover, or add one by hand.',
            icon: LucideIcons.bookOpen,
            actionLabel: 'Add your first book',
            onAction: _add,
          ),
          noMatch: NxEmptyState(
            title: 'Nothing on this shelf',
            body: searched.isNotEmpty ? 'No books match “$searched”.' : 'Try another reading status.',
            icon: LucideIcons.search,
          ),
        ),
      ],
    );

    if (current == null) return page;
    return ArtAmbient(media: MediaImage.fromJson(current.obj('media')), url: current.str('image_url'), child: page);
  }
}

class _ReadingStage extends StatelessWidget {
  const _ReadingStage({required this.book, required this.finishing, required this.onFinish, required this.onAdd});

  final Json book;
  final bool finishing;
  final VoidCallback onFinish;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final (title, accent) = splitBookTitle(book.text('title'));
    final started = readableDate(book.str('started_at'));
    return NxStage(
      art: StageArt.portrait,
      eyebrow: 'Reading now',
      title: title,
      accent: accent,
      lede: [bookAuthors(book), if (started != null) 'started $started'].join(' · '),
      visual: NxImage(
        media: MediaImage.fromJson(book.obj('media')),
        url: book.str('image_url'),
        variant: MediaVariant.hero,
        fallbackIcon: LucideIcons.bookOpen,
        semanticLabel: book.text('title'),
      ),
      actions: [
        NxButton('Finished it', icon: LucideIcons.check, loading: finishing, onPressed: onFinish),
        NxButton(
          'Open book',
          variant: NxButtonVariant.secondary,
          onPressed: () => context.push('/library/books/${book.integer('id')}'),
        ),
        NxIconButton(LucideIcons.plus, tooltip: 'Add a book', filled: true, onPressed: onAdd),
      ],
    );
  }
}

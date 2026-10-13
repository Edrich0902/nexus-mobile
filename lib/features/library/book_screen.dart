import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/core/media/pick_image.dart';
import 'package:nexus_mobile/design/art_ambient.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/library/book_sheets.dart';
import 'package:nexus_mobile/features/library/library_api.dart';
import 'package:nexus_mobile/features/library/library_helpers.dart';

/// One book (web LibraryBookView): cover-tinted stage with the next reading
/// step, the description, your notes and the facts.
class BookScreen extends ConsumerStatefulWidget {
  const new({required this.id, super.key});

  final int id;

  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  bool _advancing = false;

  Future<void> _advance(Json book) async {
    setState(() => _advancing = true);
    try {
      await ref.read(libraryApiProvider).advance(book);
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Future<void> _cover(Json book) async {
    final image = await pickAndUploadImage(
      context,
      ref,
      collection: 'library',
      attachType: 'library_book',
      attachId: widget.id,
      title: '${book.text('title')} · cover',
    );
    if (image != null) ref.read(libraryApiProvider).imageAttached(widget.id);
  }

  Future<void> _remove() async {
    final ok = await showNxConfirm(context, message: 'Remove this book from your library?', confirmLabel: 'Remove');
    if (!ok || !mounted) return;
    try {
      await ref.read(libraryApiProvider).remove(widget.id);
      if (mounted) context.go('/library');
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NxAsync(
      value: ref.watch(bookProvider(widget.id)),
      onRetry: () => ref.invalidate(bookProvider(widget.id)),
      loading: const NxPage(children: [NxPageSkeleton()]),
      data: _page,
    );
  }

  Widget _page(Json b) {
    final c = context.nx;
    final catalog = b.obj('catalog');
    final status = b.str('status');
    final media = MediaImage.fromJson(b.obj('media'));
    final url = b.str('image_url');
    final hasArt = media != null || url != null;
    final (title, accent) = splitBookTitle(b.text('title'));
    final since = readableDate(b.str('started_at'));
    final done = readableDate(b.str('finished_at'));
    final eyebrow = switch (status) {
      'reading' => since != null ? 'Reading since $since' : 'Reading',
      'read' => done != null ? 'Finished $done' : 'Read',
      _ => bookStatusLabel(status),
    };
    final pages = catalog?.integer('page_count');
    final lede = [
      bookAuthors(b),
      catalog?.integer('publish_year')?.toString(),
      if (pages != null) '$pages pages',
    ].whereType<String>().join(' · ');
    final next = switch (status) {
      'want' => 'Start reading',
      'reading' => 'Finished it',
      _ => null,
    };
    final description = catalog?.str('description');
    final notes = b.str('notes');

    return ArtAmbient(
      media: media,
      url: url,
      child: NxPage(
        onRefresh: () async {
          ref.invalidate(bookProvider(widget.id));
          await ref.read(bookProvider(widget.id).future);
        },
        children: [
          NxStage(
            art: StageArt.portrait,
            eyebrow: eyebrow,
            title: title,
            accent: accent,
            lede: lede,
            visual: NxArtWell(
              media: media,
              url: url,
              label: b.text('title'),
              addLabel: 'Add a cover',
              onAdd: () => _cover(b),
            ),
            actions: [
              if (next != null) NxButton(next, loading: _advancing, onPressed: () => _advance(b)),
              NxButton(
                'Edit',
                icon: LucideIcons.pencil,
                variant: NxButtonVariant.secondary,
                onPressed: () => showEditBookSheet(context, b),
              ),
              if (b.str('match_status') != 'matched')
                NxIconButton(
                  LucideIcons.search,
                  tooltip: 'Match in Open Library',
                  filled: true,
                  onPressed: () => showMatchBookSheet(context, widget.id),
                ),
              NxIconButton(
                LucideIcons.image,
                tooltip: hasArt ? 'Change cover' : 'Add a cover',
                filled: true,
                onPressed: () => _cover(b),
              ),
              NxIconButton(LucideIcons.trash2, tooltip: 'Remove book', filled: true, onPressed: _remove),
            ],
          ),
          const SizedBox(height: 24),
          NxPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AT A GLANCE', style: NxText.label(context, size: 11)),
                const SizedBox(height: 14),
                if (b.number('rating') case final r?) ...[NxRating(r, size: 20), const SizedBox(height: 14)],
                NxFacts([
                  ('Status', bookStatusLabel(status)),
                  ('Published', catalog?.integer('publish_year')?.toString()),
                  ('Pages', pages?.toString()),
                  ('ISBN', b.str('isbn') ?? catalog?.str('isbn_13') ?? catalog?.str('isbn_10')),
                  ('Started', readableDate(b.str('started_at'))),
                  ('Finished', readableDate(b.str('finished_at'))),
                ], columns: 2),
                const SizedBox(height: 12),
                Text(bookMatchLabel[b.str('match_status')] ?? '', style: NxText.muted(context)),
              ],
            ),
          ),
          if (description != null) ...[
            const NxSectionHeader('About the book'),
            Text(description, style: NxText.sans(size: 16, color: c.ink2, height: 1.7)),
          ],
          const NxSectionHeader('Your notes'),
          if (notes != null)
            Text(notes, style: NxText.sans(size: 16, color: c.ink2, height: 1.7))
          else
            GestureDetector(
              onTap: () => showEditBookSheet(context, b),
              child: Text(
                'Add a note about this book',
                style: NxText.sans(weight: FontWeight.w500, color: c.acc),
              ),
            ),
        ],
      ),
    );
  }
}

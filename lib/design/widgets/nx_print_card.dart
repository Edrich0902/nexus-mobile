import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/palettes.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_data.dart';
import 'package:nexus_mobile/design/widgets/nx_media.dart';
import 'package:nexus_mobile/design/widgets/nx_motion.dart';

/// How artwork sits on the colour panel (web `PrintArtMode`).
enum PrintArt { multiply, cutout, cover, photo }

enum PrintTone { busy, quiet, error }

/// Everything a fingerprint card shows (web `PrintModel`).
class PrintModel {
  const new({
    required this.key,
    required this.route,
    required this.title,
    required this.head,
    required this.artMode,
    required this.icon,
    required this.fallbackBg,
    required this.foot,
    this.by,
    this.headRight,
    this.media,
    this.src,
    this.notes = const [],
    this.tags,
    this.profile,
    this.status,
    this.progress,
    this.blurb,
    this.facts = const [],
    this.cooked,
    this.footMono = false,
    this.pair,
    this.rating,
    this.favourite = false,
  });

  final Object key;
  final String route;
  final String title;
  final String? by;
  final String head;
  final String? headRight;
  final PrintArt artMode;
  final MediaImage? media;
  final String? src;
  final IconData icon;
  final Color fallbackBg;
  final List<String> notes;
  final List<String>? tags;
  final List<ProfileAxis>? profile;
  final (String, PrintTone)? status;

  /// (step 1–3, left, right)
  final (int, String, String?)? progress;
  final String? blurb;
  final List<(String, String)> facts;
  final (int, String?)? cooked;
  final String foot;
  final bool footMono;
  final String? pair;
  final double? rating;
  final bool favourite;

  /// Thumb URL used for the panel palette lookup.
  String? paletteUrl(CloudinaryDelivery d) =>
      d.url(media ?? (src == null ? null : MediaImage(url: src)), MediaVariant.thumb) ?? src;
}

/// Fingerprint card (web NxPrintCard at phone width).
class NxPrintCard extends ConsumerWidget {
  const new({required this.print, required this.onTap, this.note, super.key});

  final PrintModel print;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final delivery = ref.watch(cloudinaryProvider);
    final palette = ref.watch(paletteCacheProvider.select((m) => m[print.paletteUrl(delivery)]));
    final panel = panelColour(palette, print.fallbackBg);
    final panelInk = inkFor(panel);
    final match = note == null ? null : print.notes.contains(note);
    final shown = (print.tags ?? print.notes).take(4).toList();
    final tags = note != null && (match ?? false) && !shown.contains(note) ? [note!, ...shown.take(3)] : shown;
    final hasArt = print.media != null || print.src != null;

    Widget art() {
      if (!hasArt) return Center(child: Icon(print.icon, size: 34, color: panelInk.withValues(alpha: .7)));
      final image = NxImage(
        media: print.media,
        url: print.src,
        fit: print.artMode == PrintArt.photo ? BoxFit.cover : BoxFit.contain,
        background: Colors.transparent,
        fallbackIcon: print.icon,
      );
      return switch (print.artMode) {
        PrintArt.photo => image,
        PrintArt.multiply => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ColorFiltered(colorFilter: ColorFilter.mode(panel, BlendMode.multiply), child: image),
        ),
        PrintArt.cutout => Padding(padding: const EdgeInsets.all(6), child: image),
        PrintArt.cover => Center(
          child: FractionallySizedBox(
            widthFactor: .76,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(color: Color(0x8C000000), blurRadius: 30, offset: Offset(0, 18), spreadRadius: -12),
                  ],
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(4), child: image),
              ),
            ),
          ),
        ),
      };
    }

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: NxMotion.ease,
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NxRadius.xxl),
        border: Border.all(color: (match ?? false) ? c.acc.withValues(alpha: .6) : c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: panel),
                  art(),
                  if (print.favourite)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.amb.withValues(alpha: .72)),
                        child: Icon(LucideIcons.heart, size: 14, color: c.acc, semanticLabel: 'Favourite'),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            print.head,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NxText.sans(size: 12, color: c.ink3),
                          ),
                        ),
                        if (print.headRight != null)
                          Text(print.headRight!, style: NxText.sans(size: 12, color: c.ink3)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      print.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NxText.serif(size: 22, height: 1.05, color: c.ink).copyWith(letterSpacing: -.2),
                    ),
                    if (print.by != null && print.by!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          print.by!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NxText.sans(size: 13, color: c.ink2),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (print.profile != null)
                      Row(
                        children: [
                          NxRadar(print.profile!.map((a) => a.value).toList(), size: 60),
                          const SizedBox(width: 14),
                          Expanded(child: NxMeters(print.profile!.take(3).toList(), stacked: true)),
                        ],
                      )
                    else if (print.status != null)
                      _Status(text: print.status!.$1, tone: print.status!.$2),
                    if (print.progress != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(print.progress!.$2, style: NxText.sans(size: 12, color: c.ink3)),
                          if (print.progress!.$3 != null)
                            Text(print.progress!.$3!, style: NxText.sans(size: 12, color: c.ink3)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var s = 1; s <= 3; s++)
                            Expanded(
                              child: Container(
                                height: 6,
                                margin: EdgeInsets.only(right: s < 3 ? 4 : 0),
                                decoration: BoxDecoration(
                                  color: s <= print.progress!.$1 ? c.acc : c.tint2,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (print.facts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final (label, value) in print.facts)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: c.tint,
                                  borderRadius: BorderRadius.circular(NxRadius.sm),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label, maxLines: 1, style: NxText.sans(size: 10.5, color: c.ink3)),
                                    Text(
                                      value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: NxText.sans(size: 13.5, weight: FontWeight.w600, color: c.ink),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (print.blurb != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        print.blurb!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: NxText.sans(size: 12.5, color: c.ink2, height: 1.4),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in tags)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: t == note ? c.acc : c.tint,
                                borderRadius: BorderRadius.circular(NxRadius.pill),
                                border: Border.all(color: t == note ? c.acc : c.line),
                              ),
                              child: Text(
                                t,
                                style: NxText.sans(
                                  size: 11.5,
                                  weight: t == note ? FontWeight.w600 : FontWeight.w400,
                                  color: t == note ? c.amb : c.ink2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              print.pair != null ? 'Pairs with ${print.pair}' : print.foot,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: print.footMono ? NxText.mono(color: c.ink3) : NxText.sans(size: 12, color: c.ink3),
                            ),
                          ),
                          NxRating(print.rating, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedOpacity(
      opacity: match == false ? .28 : 1,
      duration: const Duration(milliseconds: 350),
      curve: NxMotion.ease,
      child: AnimatedScale(
        scale: match == false ? .985 : 1,
        duration: const Duration(milliseconds: 350),
        curve: NxMotion.ease,
        child: Semantics(
          button: true,
          label: print.title,
          child: NxPressable(onTap: onTap, scale: .985, child: card),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const new({required this.text, required this.tone});

  final String text;
  final PrintTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(NxRadius.md)),
      child: Row(
        children: [
          if (tone == PrintTone.busy)
            const NxLiveDot()
          else
            Icon(
              tone == PrintTone.error ? LucideIcons.circleAlert : LucideIcons.sparkles,
              size: 14,
              color: tone == PrintTone.error ? NexusColors.bad : c.ink3,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: NxText.sans(size: 12.5, color: c.ink2)),
          ),
        ],
      ),
    );
  }
}

/// Shared-note filter above a collection of prints (web NxNoteFilter).
class NxNoteFilter extends StatelessWidget {
  const new({required this.options, required this.value, required this.onChanged, this.label = 'Notes', super.key});

  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: NxText.label(context, size: 11).copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 8),
          NxChipRow(
            children: [
              for (final o in options) NxChip(o, selected: o == value, onTap: () => onChanged(o == value ? null : o)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Collection of prints with the note filter (web CollectionPrints).
class NxPrintCollection extends ConsumerStatefulWidget {
  const new({required this.prints, required this.onOpen, this.filterLabel = 'Notes', super.key});

  final List<PrintModel> prints;
  final ValueChanged<PrintModel> onOpen;
  final String filterLabel;

  @override
  ConsumerState<NxPrintCollection> createState() => _NxPrintCollectionState();
}

class _NxPrintCollectionState extends ConsumerState<NxPrintCollection> {
  String? _note;

  @override
  Widget build(BuildContext context) {
    final delivery = ref.watch(cloudinaryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(paletteCacheProvider.notifier).want(widget.prints.map((p) => p.paletteUrl(delivery)));
    });
    final options = widget.prints.length < 2 ? <String>[] : topNotes(widget.prints.map((p) => p.notes).toList());
    final note = options.contains(_note) ? _note : null;
    return Column(
      children: [
        NxNoteFilter(
          options: options.length > 1 ? options : const [],
          value: note,
          label: widget.filterLabel,
          onChanged: (v) => setState(() => _note = v),
        ),
        const SizedBox(height: 16),
        for (final (i, p) in widget.prints.indexed)
          Padding(
            key: ValueKey(p.key),
            padding: const EdgeInsets.only(bottom: 12),
            child: NxRise(
              index: i,
              distance: 18,
              child: NxPrintCard(print: p, note: note, onTap: () => widget.onOpen(p)),
            ),
          ),
      ],
    );
  }
}

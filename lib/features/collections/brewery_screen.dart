import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/drinks_api.dart';
import 'package:nexus_mobile/features/collections/prints.dart';
import 'package:url_launcher/url_launcher.dart';

/// One brewery and the beers you've linked to it (web BeerBreweryView).
class BreweryScreen extends ConsumerWidget {
  const BreweryScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brewery = ref.watch(breweryProvider(id));
    return NxAsync(
      value: brewery,
      onRetry: () => ref.invalidate(breweryProvider(id)),
      loading: const NxPage(children: [NxPageSkeleton(art: false)]),
      data: (b) => _page(context, ref, b),
    );
  }

  Widget _page(BuildContext context, WidgetRef ref, Json b) {
    final place = [b.str('city'), b.str('state_province'), b.str('country')].whereType<String>().join(', ');
    final source = b.str('source') == 'openbrewerydb' ? 'Open Brewery DB' : 'Added by you';
    final website = b.str('website_url');
    final beers = ref.watch(breweryBeersProvider(id));
    return NxPage(
      onRefresh: () async {
        ref
          ..invalidate(breweryProvider(id))
          ..invalidate(breweryBeersProvider(id));
        await ref.read(breweryProvider(id).future);
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: [b.str('brewery_type'), source].whereType<String>().join(' · '),
          title: b.text('name', 'Brewery'),
          lede: place.isEmpty ? null : place,
          actions: [
            if (Uri.tryParse(website ?? '') case final uri? when uri.scheme.startsWith('http'))
              NxButton(
                'Website',
                icon: LucideIcons.externalLink,
                variant: NxButtonVariant.secondary,
                onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
              ),
          ],
        ),
        NxSectionHeader('Your beers from ${b.text('name', 'here')}'),
        NxAsync(
          value: beers,
          loading: const NxSkeleton(height: 220, radius: NxRadius.xxl),
          data: (list) => list.isEmpty
              ? const NxEmptyState(
                  compact: true,
                  title: 'None logged yet',
                  body: 'Beers you link to this brewery appear here.',
                  icon: LucideIcons.beer,
                )
              : NxPrintCollection(prints: list.map(beerPrint).toList(), onOpen: (p) => context.push(p.route)),
        ),
      ],
    );
  }
}

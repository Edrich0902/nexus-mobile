import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/pick_image.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// Shared profile header + Details / Sessions pills (web ProfileLayoutView).
class ProfileFrame extends ConsumerWidget {
  const new({required this.tab, required this.children, this.onRefresh, super.key});

  final String tab;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final user = ref.watch(currentUserProvider);
    final parts = (user?.name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final title = parts.length < 2 ? (parts.firstOrNull ?? 'Your') : parts.sublist(0, parts.length - 1).join(' ');
    final accent = parts.length < 2 ? (parts.isEmpty ? 'profile' : null) : parts.last;
    final since = user?.createdAt;

    return NxPage(
      onRefresh: onRefresh,
      children: [
        NxStage(
          eyebrow: since == null ? 'Profile' : 'Profile · member since ${DateFormat('MMMM y').format(since)}',
          title: title,
          accent: accent,
          lede: user?.email,
          visual: user?.media != null
              ? NxImage(media: user!.media, variant: MediaVariant.avatar, avatar: true, semanticLabel: user.name)
              : Container(
                  color: c.acc.withValues(alpha: .22),
                  alignment: Alignment.center,
                  child: Text(user?.initials ?? '?', style: NxText.display(size: 56, color: c.acc)),
                ),
          actions: [
            NxButton(
              user?.media != null ? 'Change photo' : 'Add a photo',
              icon: LucideIcons.image,
              variant: NxButtonVariant.secondary,
              onPressed: user == null
                  ? null
                  : () async {
                      final image = await pickAndUploadImage(
                        context,
                        ref,
                        collection: 'avatar',
                        attachType: 'user',
                        attachId: user.id,
                        role: 'avatar',
                        title: 'Profile photo',
                      );
                      if (image != null) {
                        ref.read(authProvider.notifier).updateUser(user.copyWith(media: image));
                      }
                    },
            ),
          ],
        ),
        const SizedBox(height: 24),
        NxPillNav<String>(
          items: const [('details', 'Details'), ('sessions', 'Sessions')],
          value: tab,
          onChanged: (v) => context.go(v == 'details' ? '/profile' : '/profile/sessions'),
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final _name = TextEditingController(text: ref.read(currentUserProvider)?.name ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final json = asJson(await ref.read(apiClientProvider).patch('/auth/profile', data: {'name': name}));
      ref.read(authProvider.notifier).updateUser(User.fromJson(json));
      if (mounted) showNxToast(context, 'Profile saved');
    } on Object catch (e) {
      setState(() => _error = ApiError.from(e).field('name') ?? ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return ProfileFrame(
      tab: 'details',
      onRefresh: () => ref.read(authProvider.notifier).reloadUser(),
      children: [
        NxPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NxTextField(
                label: 'Name',
                controller: _name,
                error: _error,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              NxFacts([
                ('Email', user?.email),
                ('Member since', user?.createdAt == null ? null : DateFormat('d MMM y').format(user!.createdAt!)),
              ], columns: 2),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: NxButton('Save', onPressed: _save, loading: _saving),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

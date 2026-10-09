import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/core/media/media_upload.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// Camera or library → compress → `POST /media` (signed server-side to
/// Cloudinary). Reused by profile photo, covers and the media vault.
Future<MediaImage?> pickAndUploadImage(
  BuildContext context,
  WidgetRef ref, {
  required String collection,
  String? attachType,
  int? attachId,
  String role = 'cover',
  String title = 'Add a photo',
}) async {
  final source = await showNxSheet<ImageSource>(
    context,
    title: title,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NxListRow(
          label: 'Take a photo',
          icon: LucideIcons.camera,
          onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
        ),
        NxListRow(
          label: 'Choose from library',
          icon: LucideIcons.images,
          onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return null;
  final picked = await ImagePicker().pickImage(source: source, requestFullMetadata: false);
  if (picked == null || !context.mounted) return null;

  final progress = ValueNotifier<double>(0);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final banner = messenger?.showSnackBar(
    SnackBar(
      duration: const Duration(minutes: 2),
      content: ValueListenableBuilder(
        valueListenable: progress,
        builder: (_, v, _) => Row(
          children: [
            const Text('Uploading'),
            const SizedBox(width: 12),
            Expanded(child: LinearProgressIndicator(value: v == 0 ? null : v)),
          ],
        ),
      ),
    ),
  );
  try {
    final json = await ref
        .read(mediaUploaderProvider)
        .upload(
          File(picked.path),
          collection: collection,
          attachType: attachType,
          attachId: attachId,
          role: role,
          onProgress: (v) => progress.value = v,
        );
    banner?.close();
    return MediaImage.fromJson(json);
  } on Object catch (e) {
    banner?.close();
    if (context.mounted) showApiError(context, e, 'Upload failed.');
    return null;
  } finally {
    progress.dispose();
  }
}

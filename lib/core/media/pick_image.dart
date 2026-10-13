import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
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
  final banner = showNxToast(context, 'Uploading photo', progress: progress, duration: const Duration(minutes: 2));
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
    banner.close();
    return MediaImage.fromJson(json);
  } on Object catch (e) {
    banner.close();
    if (context.mounted) showApiError(context, e, 'Upload failed.');
    return null;
  } finally {
    // The toast still listens while it animates out.
    Timer(const Duration(seconds: 1), progress.dispose);
  }
}

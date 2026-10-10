import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';

Future<ImageSource?> showMediaSourceSheet({
  required BuildContext context,
  required bool video,
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              video ? 'Добавить видео' : 'Добавить фото',
              style: AppText.titleH2(),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                video ? Icons.videocam_outlined : Icons.camera_alt_outlined,
              ),
              title: Text(video ? 'Записать видео' : 'Сделать фото'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                video ? 'Выбрать видео из галереи' : 'Выбрать фото из галереи',
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

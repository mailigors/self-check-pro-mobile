import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../../core/files/open_attachment.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/checklist_models.dart';

// Keep newly uploaded files available before the answer has a server ID.
final attachmentCacheProvider = Provider.autoDispose
    .family<Map<int, DownloadedFile>, int>((ref, checklistId) => {});

typedef AttachmentKey = ({int checklistId, int? answerId, AttachmentRef file});

final attachmentDataProvider = FutureProvider.autoDispose
    .family<DownloadedFile, AttachmentKey>((ref, key) async {
      final cached = ref.watch(
        attachmentCacheProvider(key.checklistId),
      )[key.file.attachmentId];
      if (cached != null) return cached;
      if (key.answerId == null) {
        throw const ApiException(
          message: 'Сохраните чек-лист перед просмотром вложения',
        );
      }
      final downloaded = await ref
          .read(apiClientProvider)
          .download(
            '/checklists/${key.checklistId}/answer/${key.answerId}/attachments/${key.file.attachmentId}',
            fallbackFilename:
                key.file.filename ?? 'attachment_${key.file.attachmentId}',
          );
      return DownloadedFile(
        bytes: downloaded.bytes,
        filename: downloaded.filename,
        mimeType:
            lookupMimeType(
              downloaded.filename,
              headerBytes: downloaded.bytes.take(32).toList(),
            ) ??
            key.file.contentType ??
            downloaded.mimeType,
      );
    });

bool isImageAttachment(AttachmentRef file, String kind) {
  if (file.contentType?.startsWith('image/') == true) return true;
  final name = file.filename?.toLowerCase() ?? '';
  return RegExp(r'\.(png|jpe?g|gif|webp|bmp)$').hasMatch(name) ||
      kind == 'photo';
}

class AttachmentFileButton extends ConsumerStatefulWidget {
  const AttachmentFileButton({
    super.key,
    required this.attachmentKey,
    required this.kind,
    this.onRemove,
  });

  final AttachmentKey attachmentKey;
  final String kind;
  final VoidCallback? onRemove;

  @override
  ConsumerState<AttachmentFileButton> createState() =>
      _AttachmentFileButtonState();
}

class _AttachmentFileButtonState extends ConsumerState<AttachmentFileButton> {
  bool _opening = false;

  Future<void> _open(bool image) async {
    if (_opening) return;
    // Open a browser tab during the user gesture, before fetching the bytes.
    final target = image ? null : prepareAttachmentPreview();
    setState(() => _opening = true);
    try {
      final file = await ref.read(
        attachmentDataProvider(widget.attachmentKey).future,
      );
      if (!mounted) {
        target?.close();
        return;
      }
      if (image) {
        setState(() => _opening = false);
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text(file.filename, overflow: TextOverflow.ellipsis),
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.memory(
                    file.bytes,
                    errorBuilder: (_, _, _) =>
                        const Text('Не удалось отобразить изображение'),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        await target!.open(file);
      }
    } catch (error) {
      target?.close();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is ApiException ? error.message : '$error'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () {
                ref.invalidate(attachmentDataProvider(widget.attachmentKey));
                _open(image);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.attachmentKey.file;
    final image = isImageAttachment(file, widget.kind);
    final video =
        widget.kind == 'video' ||
        file.contentType?.startsWith('video/') == true ||
        RegExp(r'\.(mp4|mov|m4v|webm|avi)$')
            .hasMatch(file.filename?.toLowerCase() ?? '');
    final typeLabel = video
        ? 'Видео'
        : image
        ? 'Фото'
        : 'Файл';
    final typeIcon = video
        ? Icons.videocam_outlined
        : image
        ? Icons.image_outlined
        : Icons.insert_drive_file_outlined;
    final name =
        file.filename ??
        ref
            .read(
              attachmentCacheProvider(widget.attachmentKey.checklistId),
            )[file.attachmentId]
            ?.filename ??
        'Файл ${file.attachmentId}';
    return Material(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: name,
              child: InkWell(
                onTap: () => _open(image),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (_opening)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(typeIcon, size: 24, color: AppColors.brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              typeLabel,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.brand),
                            ),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.onRemove != null)
            IconButton(
              tooltip: 'Удалить вложение',
              color: AppColors.error,
              onPressed: widget.onRemove,
              icon: const Icon(Icons.close, size: 20),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/json_helpers.dart';
import '../widgets/app_button.dart';
import 'save_downloaded_file.dart';

class FileDelivery {
  FileDelivery({Future<ShareResult> Function(ShareParams)? send})
    : _send = send ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams) _send;
  Future<void> save(DownloadedFile file) =>
      saveDownloadedFile(bytes: file.bytes, filename: file.filename);

  Future<void> share(DownloadedFile file, Rect origin) async {
    await _send(
      ShareParams(
        files: [XFile.fromData(file.bytes, mimeType: file.mimeType)],
        fileNameOverrides: [sanitizeFilename(file.filename)],
        title: 'Отчёт SelfCheckPro',
        subject: 'Отчёт SelfCheckPro',
        sharePositionOrigin: origin,
        downloadFallbackEnabled: false,
      ),
    );
  }
}

final fileDeliveryProvider = Provider<FileDelivery>((ref) => FileDelivery());

Future<void> showDownloadedFileActions({
  required BuildContext context,
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  showDragHandle: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _FileActions(
    file: DownloadedFile(bytes: bytes, filename: filename, mimeType: mimeType),
  ),
);

class _FileActions extends ConsumerStatefulWidget {
  const _FileActions({required this.file});
  final DownloadedFile file;
  @override
  ConsumerState<_FileActions> createState() => _FileActionsState();
}

class _FileActionsState extends ConsumerState<_FileActions> {
  String? _busy;
  String? _error;

  Future<void> _run(String action, BuildContext buttonContext) async {
    if (_busy != null) return;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = action;
      _error = null;
    });
    try {
      final delivery = ref.read(fileDeliveryProvider);
      if (action == 'share') {
        await delivery.share(widget.file, origin);
      } else {
        await delivery.save(widget.file);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = (kIsWeb || error is UnsupportedError) && action == 'share'
              ? 'Отправка файлов недоступна в этом браузере или системе. Можно сохранить файл и отправить его из почты или другого приложения.'
              : action == 'share'
              ? 'Не удалось открыть меню отправки. Попробуйте ещё раз или сохраните файл.'
              : 'Не удалось сохранить файл. Попробуйте ещё раз.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Отчёт готов', style: AppText.titleH2())),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: _busy == null
                    ? () => Navigator.of(context).pop()
                    : null,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(widget.file.filename, style: AppText.bodyH4()),
          const SizedBox(height: 20),
          Builder(
            builder: (buttonContext) => AppButton(
              label: 'Поделиться',
              icon: Icons.share_outlined,
              variant: AppButtonVariant.dark,
              loading: _busy == 'share',
              onPressed: _busy == null
                  ? () => _run('share', buttonContext)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Почта, мессенджер или другое приложение',
            style: AppText.bodyH5(),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (buttonContext) => AppButton(
              label: 'Сохранить файл',
              icon: Icons.download_outlined,
              variant: AppButtonVariant.secondary,
              loading: _busy == 'save',
              onPressed: _busy == null
                  ? () => _run('save', buttonContext)
                  : null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: AppText.bodyH4(color: AppColors.error)),
          ],
        ],
      ),
    ),
  );
}

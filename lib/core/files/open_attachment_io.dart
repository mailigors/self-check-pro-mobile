import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';
import '../utils/json_helpers.dart';

class AttachmentPreviewTarget {
  Future<void> open(DownloadedFile file) async {
    final root = await getTemporaryDirectory();
    final directory = await root.createTemp('attachment_preview_');
    final path = '${directory.path}/${sanitizeFilename(file.filename)}';
    await File(path).writeAsBytes(file.bytes, flush: true);
    final result = await OpenFilex.open(path, type: file.mimeType);
    if (result.type != ResultType.done) {
      throw StateError(
        'Не удалось открыть файл. Проверьте наличие приложения для просмотра.',
      );
    }
  }

  void close() {}
}

AttachmentPreviewTarget prepareAttachmentPreview() => AttachmentPreviewTarget();

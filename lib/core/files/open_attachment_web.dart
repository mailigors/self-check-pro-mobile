import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../network/api_client.dart';

class AttachmentPreviewTarget {
  AttachmentPreviewTarget() : _window = web.window.open('', '_blank');

  final web.Window? _window;

  Future<void> open(DownloadedFile file) async {
    if (_window == null) {
      throw StateError('Разрешите открытие новой вкладки для просмотра файла.');
    }
    final blob = web.Blob(
      [file.bytes.toJS].toJS,
      web.BlobPropertyBag(type: file.mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    _window.location.href = url;
    Timer(const Duration(minutes: 10), () => web.URL.revokeObjectURL(url));
  }

  void close() => _window?.close();
}

AttachmentPreviewTarget prepareAttachmentPreview() => AttachmentPreviewTarget();

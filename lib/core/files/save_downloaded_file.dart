import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveDownloadedFile({
  required Uint8List bytes,
  required String filename,
}) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Сохранить файл',
    fileName: filename,
    bytes: bytes,
  );
}

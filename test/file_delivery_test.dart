import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:checklist_flutter/core/files/downloaded_file_actions.dart';
import 'package:checklist_flutter/core/network/api_client.dart';
import 'package:checklist_flutter/core/theme/app_theme.dart';

class RecordingDelivery extends FileDelivery {
  final List<DownloadedFile> shared = [];
  final List<DownloadedFile> saved = [];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> share(DownloadedFile file, Rect origin) async {
    shared.add(file);
    if (fail) throw UnsupportedError('Not supported');
    if (pending != null) await pending!.future;
  }

  @override
  Future<void> save(DownloadedFile file) async {
    saved.add(file);
  }
}

void main() {
  for (final mime in [
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ]) {
    test('shares file bytes, MIME, filename and iPad anchor: $mime', () async {
      final file = DownloadedFile(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: mime == 'application/pdf' ? 'отчёт.pdf' : 'отчёт.xlsx',
        mimeType: mime,
      );
      ShareParams? captured;
      final delivery = FileDelivery(
        send: (params) async {
          captured = params;
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      const origin = Rect.fromLTWH(20, 300, 200, 56);
      await delivery.share(file, origin);
      expect(await captured!.files!.single.readAsBytes(), file.bytes);
      expect(captured!.files!.single.mimeType, mime);
      expect(captured!.fileNameOverrides, [file.filename]);
      expect(captured!.sharePositionOrigin, origin);
      expect(captured!.subject, 'Отчёт SelfCheckPro');
      expect(captured!.downloadFallbackEnabled, isFalse);
    });
  }

  Future<void> launch(WidgetTester tester, RecordingDelivery delivery) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fileDeliveryProvider.overrideWithValue(delivery)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDownloadedFileActions(
                  context: context,
                  bytes: Uint8List.fromList([1, 2, 3]),
                  filename: 'report.pdf',
                  mimeType: 'application/pdf',
                ),
                child: const Text('PDF'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
  }

  testWidgets('share sends file once and does not save it', (tester) async {
    final delivery = RecordingDelivery()..pending = Completer<void>();
    await launch(tester, delivery);
    await tester.tap(find.text('Поделиться'));
    await tester.pump();
    await tester.tap(find.text('Сохранить файл'));
    await tester.pump();
    expect(delivery.shared.length, 1);
    expect(delivery.saved, isEmpty);
    expect(delivery.shared.single.filename, 'report.pdf');
    delivery.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Отчёт готов'), findsNothing);
  });

  testWidgets('unsupported sharing retains the save action', (tester) async {
    final delivery = RecordingDelivery()..fail = true;
    await launch(tester, delivery);
    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Отправка файлов недоступна'), findsOneWidget);
    await tester.tap(find.text('Сохранить файл'));
    await tester.pumpAndSettle();
    expect(delivery.saved.single.bytes, [1, 2, 3]);
    expect(find.text('Отчёт готов'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing report actions does not send or save', (tester) async {
    final delivery = RecordingDelivery();
    await launch(tester, delivery);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(delivery.shared, isEmpty);
    expect(delivery.saved, isEmpty);
  });
}

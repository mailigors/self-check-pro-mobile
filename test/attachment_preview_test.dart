import 'dart:convert';
import 'dart:typed_data';

import 'package:checklist_flutter/core/network/api_client.dart';
import 'package:checklist_flutter/core/widgets/app_tag.dart';
import 'package:checklist_flutter/features/checklists/domain/checklist_models.dart';
import 'package:checklist_flutter/features/checklists/presentation/filling/attachment_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('цвета всех статусов, включая ещё не начатый чек-лист', () {
    final now = DateTime(2026, 10, 10);
    UiChecklistStatus resolve(ChecklistStatusCode code, {DateTime? startAt}) =>
        UiChecklistStatus.resolve(
          ChecklistSummary(
            id: 1,
            status: ChecklistStatusInfo(code: code),
            startAt: startAt,
          ),
          now,
        );
    expect(resolve(ChecklistStatusCode.completed).tone, AppTagTone.draft);
    expect(resolve(ChecklistStatusCode.inWork).tone, AppTagTone.success);
    expect(resolve(ChecklistStatusCode.draft).tone, AppTagTone.draft);
    expect(
      resolve(
        ChecklistStatusCode.draft,
        startAt: now.add(const Duration(days: 1)),
      ).tone,
      AppTagTone.error,
    );
  });

  testWidgets('показ имён фото и видео не скачивает оригиналы', (tester) async {
    const photo = (
      checklistId: 10,
      answerId: 5,
      file: AttachmentRef(attachmentId: 3, filename: 'photo.jpg'),
    );
    const video = (
      checklistId: 10,
      answerId: 5,
      file: AttachmentRef(attachmentId: 4, filename: 'video.mov'),
    );
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          for (final key in [photo, video])
            attachmentDataProvider(key).overrideWith((ref) async {
              requests++;
              throw StateError('Оригинал нельзя загружать без нажатия');
            }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AttachmentFileButton(attachmentKey: photo, kind: 'photo'),
                AttachmentFileButton(attachmentKey: video, kind: 'video'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('video.mov'), findsOneWidget);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'длинные имена не выходят за карточку, фото открывается до сохранения ответа',
    (tester) async {
      const file = AttachmentRef(
        attachmentId: 1,
        filename:
            'image_picker_34C22ADE-DA4B-4411-A494-B91678E81_very_long_name.png',
        contentType: 'image/png',
      );
      final downloaded = DownloadedFile(
        bytes: Uint8List.fromList(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
        ),
        filename: file.filename!,
        mimeType: file.contentType!,
      );
      var removed = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attachmentCacheProvider(10).overrideWith((ref) => {1: downloaded}),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 180,
                  child: Column(
                    children: [
                      AttachmentFileButton(
                        attachmentKey: (
                          checklistId: 10,
                          answerId: null,
                          file: file,
                        ),
                        kind: 'photo',
                        onRemove: () => removed = true,
                      ),
                      const AttachmentFileButton(
                        attachmentKey: (
                          checklistId: 10,
                          answerId: 5,
                          file: AttachmentRef(
                            attachmentId: 2,
                            filename: 'another_very_long_document_name.pdf',
                          ),
                        ),
                        kind: 'other',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(file.filename!), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text(file.filename!), findsNWidgets(2));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Удалить вложение'));
      expect(removed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

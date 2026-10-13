import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checklist_flutter/core/theme/app_theme.dart';
import 'package:checklist_flutter/core/widgets/app_confirm_sheet.dart';
import 'package:checklist_flutter/features/checklists/presentation/filling/media_source_sheet.dart';

void main() {
  Future<void> launch(
    WidgetTester tester,
    VoidCallback Function(BuildContext) action,
  ) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('fonts/Manrope.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet-preview'),
        child: MaterialApp(
          theme: AppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: action(context),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('sheet-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/testflight-checks')
        ..createSync(recursive: true);
      File('${directory.path}/$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'media sheet scrolls to all actions on a small screen at large text',
    (tester) async {
      await launch(
        tester,
        (context) => () {
          showMediaSourceSheet(context: context, video: true);
        },
      );
      await tester.ensureVisible(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('Отмена')).dy,
        lessThanOrEqualTo(360),
      );
      await capture(tester, 'media-sheet');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить видео'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmation sheet keeps long content and buttons reachable', (
    tester,
  ) async {
    await launch(
      tester,
      (context) => () {
        showAppConfirmSheet(
          context: context,
          title: 'Завершить проверку?',
          message: 'Проверьте ответы перед завершением. После отправки результаты будут доступны для просмотра.',
        );
      },
    );
    await tester.ensureVisible(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.text('Подтвердить')).dy,
      lessThanOrEqualTo(360),
    );
    await capture(tester, 'confirm-sheet');
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(find.text('Завершить проверку?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

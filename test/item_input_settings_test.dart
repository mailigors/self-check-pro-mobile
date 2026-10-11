import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checklist_flutter/core/theme/app_theme.dart';
import 'package:checklist_flutter/features/checklists/domain/checklist_models.dart';
import 'package:checklist_flutter/features/checklists/data/checklist_repository_impl.dart';
import 'package:checklist_flutter/features/checklists/presentation/filling/filling_controller.dart';
import 'package:checklist_flutter/features/checklists/presentation/filling/item_answer_card.dart';

import 'support/redesign_fixtures.dart';

void main() {
  test('normalizes API settings without losing choice values', () {
    for (final raw in [
      {'options': '[{"text":"Исправно","weight":1},"Неисправно"]'},
      jsonEncode({
        'options': [
          {'text': 'Исправно', 'weight': 1},
          'Неисправно',
        ],
      }),
      '{ui_hint=radio, options=[Исправно, Неисправно]}',
      {'{ui_hint': 'radio, options=[Исправно, Неисправно]}'},
      ['Исправно', 'Неисправно'],
    ]) {
      expect(ItemSettings.fromJson(raw).options, ['Исправно', 'Неисправно']);
    }
    final settings = ItemSettings.fromJson({
      'minLength': 2,
      'max_length': 10,
      'options': [
        {'value': 'ok', 'label': 'Исправно'},
      ],
    });
    expect(settings.minLength, 2);
    expect(settings.maxLength, 10);
    expect(settings.options, ['ok']);
    expect(settings.optionLabels['ok'], 'Исправно');
  });

  Future<ProviderContainer> launch(
    WidgetTester tester,
    String type,
    dynamic settings,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        checklistRepositoryProvider.overrideWithValue(
          PreviewChecklistRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(fillingControllerProvider(1).future),
    );
    final item = TemplateItem.fromJson({
      'id': 6,
      'name': 'Тест',
      'question_type': type,
      'settings': settings,
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  final state = ref
                      .watch(fillingControllerProvider(1))
                      .valueOrNull!;
                  return ItemAnswerCard(
                    checklistId: 1,
                    item: item,
                    answer: state.answers[6] ?? const ItemAnswer(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  for (final type in ['short_text', 'long_text']) {
    testWidgets('$type counts visible characters and retains overflow input', (
      tester,
    ) async {
      final container = await launch(tester, type, {
        'min_length': 2,
        'max_length': 5,
      });
      expect(find.text('Символов: 0 · мин 2 · макс 5'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'А👨‍👩‍👧‍👦');
      await tester.pump();
      expect(find.text('Символов: 2 · мин 2 · макс 5'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();
      expect(find.text('Символов: 6 · мин 2 · макс 5'), findsOneWidget);
      expect(
        container
            .read(fillingControllerProvider(1))
            .valueOrNull!
            .answers[6]!
            .value,
        '123456',
      );
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.text('Символов: 0 · мин 2 · макс 5'), findsOneWidget);
    });
  }

  testWidgets('number and dates show unset and one-sided bounds', (
    tester,
  ) async {
    await launch(tester, 'number', {'max_value': 95});
    expect(find.text('мин - · макс 95'), findsOneWidget);
    await launch(tester, 'date', {'min_date': '2026-10-10'});
    expect(find.text('мин 10.10.2026 · макс -'), findsOneWidget);
    await launch(tester, 'datetime', {
      'min_datetime': '2026-10-10T09:30:00',
      'max_datetime': '2026-10-11T18:00:00',
    });
    expect(
      find.text('мин 10.10.2026 09:30 · макс 11.10.2026 18:00'),
      findsOneWidget,
    );
    await launch(tester, 'datetime', {});
    expect(find.text('мин - · макс -'), findsOneWidget);
  });

  testWidgets('double bounds round to precision without changing the answer', (
    tester,
  ) async {
    final container = await launch(tester, 'double', {
      'min_value': 1.234567,
      'max_value': 9.876543,
      'precision': 2,
    });
    expect(find.text('мин 1,23 · макс 9,88'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '3.4567');
    await tester.pump();
    expect(
      container
          .read(fillingControllerProvider(1))
          .valueOrNull!
          .answers[6]!
          .value,
      3.4567,
    );
    await launch(tester, 'double', {
      'min_value': 1.234,
      'max_value': 9.876,
      'precision': 0,
    });
    expect(find.text('мин 1 · макс 10'), findsOneWidget);
    await launch(tester, 'double', {'max_value': 9.8, 'precision': 3});
    expect(find.text('мин - · макс 9,800'), findsOneWidget);
  });

  for (final hint in ['radio', 'dropdown', 'checkbox']) {
    testWidgets('$hint renders API choices and saves selection', (
      tester,
    ) async {
      final container = await launch(
        tester,
        hint == 'checkbox' ? 'multi_choice' : 'single_choice',
        {
          'ui_hint': hint,
          'options': '[{"value":"ok","text":"Исправно"},{"value":"bad","text":"Неисправно"}]',
        },
      );
      if (hint == 'dropdown') {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Исправно').last);
      await tester.pumpAndSettle();
      expect(
        container
            .read(fillingControllerProvider(1))
            .valueOrNull!
            .answers[6]!
            .value,
        hint == 'checkbox' ? ['ok'] : 'ok',
      );
      if (hint == 'checkbox') {
        await tester.tap(find.text('Неисправно'));
        await tester.pump();
        expect(
          container
              .read(fillingControllerProvider(1))
              .valueOrNull!
              .answers[6]!
              .value,
          ['ok', 'bad'],
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

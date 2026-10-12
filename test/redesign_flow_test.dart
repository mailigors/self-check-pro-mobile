import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:checklist_flutter/main.dart';
import 'package:checklist_flutter/features/auth/presentation/auth_controller.dart';
import 'package:checklist_flutter/features/checklists/data/checklist_repository_impl.dart';
import 'package:checklist_flutter/features/checklists/presentation/filling/filling_controller.dart';

import 'support/redesign_fixtures.dart';
import 'support/dashboard_fixtures.dart';

import 'package:checklist_flutter/features/dashboard/data/dashboard_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  Future<PreviewChecklistRepository> launch(
    WidgetTester tester, {
    bool loggedIn = true,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = PreviewChecklistRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => PreviewAuthController(authenticated: loggedIn),
          ),
          checklistRepositoryProvider.overrideWithValue(repo),
          dashboardRepositoryProvider.overrideWithValue(
            PreviewDashboardRepository(),
          ),
        ],
        child: const SelfCheckApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (loggedIn) {
      await tester.tap(find.text('Чек-листы').last);
      await tester.pumpAndSettle();
    }
    return repo;
  }

  testWidgets('report actions are available from list and completed result', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('PDF').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('demo-checklist-1.pdf'), findsOneWidget);
    expect(find.text('Поделиться'), findsOneWidget);
    expect(find.text('Сохранить файл'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Аудит_Кухня_Версия_5.3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Аудит_Кухня_Версия_5.3'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Excel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('demo-checklist-2.xlsx'), findsOneWidget);
    expect(find.text('Поделиться'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comment survives keyboard dismissal', (tester) async {
    await launch(tester);
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    final addComment = find.text('Добавить комментарий').first;
    await tester.ensureVisible(addComment);
    await tester.pumpAndSettle();
    await tester.tap(addComment);
    await tester.pumpAndSettle();
    final comment = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Комментарий',
        )
        .first;
    await tester.ensureVisible(comment);
    await tester.enterText(comment, 'Первая строка\nВторая строка');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.text('Скрыть клавиатуру'), findsOneWidget);
    await tester.tap(find.text('Скрыть клавиатуру'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SelfCheckApp)),
    );
    expect(
      container
          .read(fillingControllerProvider(1))
          .valueOrNull!
          .answers[1]!
          .comment,
      'Первая строка\nВторая строка',
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('Сохранить'), findsOneWidget);
    await tester.ensureVisible(comment);
    await tester.tap(comment);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверка'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px, enlarged text: choose object, back preserves choice, start with selected IDs',
    (tester) async {
      final repo = await launch(tester, scale: 1.4);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Начать контроль'));
      await tester.pumpAndSettle();
      expect(find.text('Объект контроля'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('ФР Хачо и Пури'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      final selectedTemplate = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Аудит_Кухня_Версия_5.3'),
      );
      await tester.scrollUntilVisible(
        selectedTemplate,
        120,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(selectedTemplate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();
      expect(repo.startedObject, 1);
      expect(repo.startedTemplate, 3);
      expect(find.text('Проверка'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completion still validates; answers save and result uses real score',
    (tester) async {
      final repo = await launch(tester);
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершить').last);
      await tester.pumpAndSettle();
      expect(repo.completions, 0);
      expect(find.text('Обязательный вопрос'), findsOneWidget);
      await tester.ensureVisible(find.text('Да').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да').first);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SelfCheckApp)),
      );
      expect(
        container
            .read(fillingControllerProvider(1))
            .valueOrNull!
            .answers[1]!
            .value,
        true,
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(repo.answers[1]!.value, true);
      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершить').last);
      await tester.pumpAndSettle();
      expect(repo.completions, 1);
      expect(find.text('88,0%'), findsOneWidget);
      expect(find.text('Возобновить'), findsOneWidget);
      await tester.tap(find.text('Возобновить'));
      await tester.pumpAndSettle();
      expect(find.text('Проверка'), findsOneWidget);
      expect(
        container
            .read(fillingControllerProvider(1))
            .valueOrNull!
            .answers[1]!
            .value,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile keeps password validation and account details', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Аудитор Групп'), findsOneWidget);
    await tester.tap(find.text('Безопасность'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Изменить пароль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить пароль'));
    await tester.pumpAndSettle();
    expect(find.text('Заполните все поля'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login fits a small screen with keyboard and reveals password', (
    tester,
  ) async {
    await launch(tester, loggedIn: false);
    await tester.enterText(find.byType(TextField).first, 'demo');
    await tester.enterText(find.byType(TextField).last, 'demo-password');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Войти'));
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Дашборд'), findsNWidgets(2));
    expect(find.text('В РАБОТЕ'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:checklist_flutter/main.dart';
import 'package:checklist_flutter/features/auth/domain/user_profile.dart';
import 'package:checklist_flutter/features/auth/presentation/auth_controller.dart';
import 'package:checklist_flutter/features/checklists/data/checklist_repository_impl.dart';
import 'package:checklist_flutter/features/dashboard/data/dashboard_repository.dart';

import 'support/dashboard_fixtures.dart';
import 'support/redesign_fixtures.dart';

class _SystemAuthController extends PreviewAuthController {
  @override
  Future<AuthState> build() async => const AuthState(
    user: UserProfile(
      id: 2,
      email: 'admin@example.com',
      fullName: 'Администратор',
      roleCode: 'SYSTEM_ADMINISTRATOR',
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  test('periods include today and cross month/year boundaries', () {
    expect(
      DashboardPeriod.week.query(DateTime(2026, 1, 2)).fromDate,
      '2025-12-27',
    );
    expect(
      DashboardPeriod.month.query(DateTime(2026, 3, 1)).fromDate,
      '2026-01-31',
    );
    expect(
      DashboardPeriod.quarter.query(DateTime(2026, 10, 12)).groupBy,
      'WEEK',
    );
  });

  test('analytics use controlResult and preserve unavailable scores', () {
    expect(
      DashboardSummary.fromJson({
        'controlResult': '78.4',
        'averageCompletion': 99,
      }).score,
      78.4,
    );
    expect(DashboardPoint.fromJson({'createdCount': 2}).score, isNull);
    expect(
      UserProfile.fromJson({
        'role': {'code': 'SYSTEM_ADMINISTRATOR', 'name': 'Администратор'},
      }).isSystemAdministrator,
      isTrue,
    );
  });

  Future<PreviewDashboardRepository> launch(
    WidgetTester tester, {
    bool failObjects = false,
    double scale = 1,
    bool system = false,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = PreviewDashboardRepository()..failObjects = failObjects;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => system ? _SystemAuthController() : PreviewAuthController(),
          ),
          checklistRepositoryProvider.overrideWithValue(
            PreviewChecklistRepository(),
          ),
          dashboardRepositoryProvider.overrideWithValue(repository),
        ],
        child: const SelfCheckApp(),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('restored session opens dashboard; period changes the query', (
    tester,
  ) async {
    final repository = await launch(tester);
    expect(find.text('Дашборд'), findsNWidgets(2));
    expect(find.text('78,4%'), findsOneWidget);
    await tester.tap(find.text('Месяц'));
    await tester.pumpAndSettle();
    final q = repository.queries.last;
    expect(
      DateTime.parse(q.toDate).difference(DateTime.parse(q.fromDate)).inDays,
      29,
    );
    await tester.tap(find.text('Квартал'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.groupBy, 'WEEK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-work tile opens filtered checklists', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Открыть список ›'));
    await tester.pumpAndSettle();
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Аудит_Кухня_Версия_5.3'), findsNothing);
    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();
    expect(find.text('Аудит_Кухня_Версия_5.3'), findsOneWidget);
    await tester.tap(find.text('Дашборд').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть список ›'));
    await tester.pumpAndSettle();
    expect(find.text('Аудит_Кухня_Версия_5.3'), findsNothing);
  });

  testWidgets(
    'system administrator selects organization before analytics load',
    (tester) async {
      final repository = await launch(tester, system: true);
      expect(repository.queries, isEmpty);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Тестовая организация').last);
      await tester.pumpAndSettle();
      expect(repository.queries.single.organisationId, 42);
      expect(find.text('78,4%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('attention opens checklist and refreshes on return', (
    tester,
  ) async {
    final repository = await launch(tester);
    await tester.scrollUntilVisible(
      find.text('Проверка с отклонением'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверка с отклонением'));
    await tester.pumpAndSettle();
    expect(find.text('Завершить'), findsOneWidget);
    final calls = repository.queries.length;
    await tester.tap(find.byTooltip('Назад').first);
    await tester.pumpAndSettle();
    expect(repository.queries.length, greaterThan(calls));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'block failure can retry without hiding other analytics at large text',
    (tester) async {
      final repository = await launch(tester, failObjects: true, scale: 1.4);
      await tester.scrollUntilVisible(
        find.text('Повторить'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить данные'), findsOneWidget);
      repository.failObjects = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('81,5%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

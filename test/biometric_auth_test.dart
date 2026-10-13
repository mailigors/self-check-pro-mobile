import 'dart:async';

import 'package:checklist_flutter/core/network/api_exception.dart';
import 'package:checklist_flutter/core/security/biometric_auth.dart';
import 'package:checklist_flutter/core/storage/token_storage.dart';
import 'package:checklist_flutter/features/auth/data/auth_repository_impl.dart';
import 'package:checklist_flutter/features/auth/domain/auth_repository.dart';
import 'package:checklist_flutter/features/auth/domain/user_profile.dart';
import 'package:checklist_flutter/features/auth/presentation/auth_controller.dart';
import 'package:checklist_flutter/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:checklist_flutter/main.dart';
import 'package:checklist_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:checklist_flutter/features/checklists/data/checklist_repository_impl.dart';

import 'support/dashboard_fixtures.dart';
import 'support/redesign_fixtures.dart';

class FakeBiometrics extends BiometricAuth {
  FakeBiometrics() : super(LocalAuthentication());
  bool result = true;
  bool platformSupported = true;
  int calls = 0;
  Completer<bool>? pending;
  @override
  bool get supported => platformSupported;
  @override
  Future<bool> authenticate() async {
    calls++;
    return pending == null ? result : pending!.future;
  }

  @override
  Future<String?> availableLabel() async => 'Face ID';
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.storage);
  final TokenStorage storage;
  int meCalls = 0;
  int loginCalls = 0;
  ApiException? error;
  UserProfile loginUser = user;
  static const user = UserProfile(
    id: 1,
    email: 'test@example.com',
    fullName: 'Тест',
  );
  @override
  Future<UserProfile> me() async {
    meCalls++;
    if (error != null) throw error!;
    return user;
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    await storage.saveTokens(access: 'new-access');
    return loginUser;
  }

  @override
  Future<void> logout() => storage.clear();
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TokenStorage storage;
  late FakeBiometrics biometrics;
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'saved-access',
      'refresh_token': 'saved-refresh',
      'biometric_login_enabled': 'true',
      'biometric_account_id': '1',
    });
    storage = TokenStorage(const FlutterSecureStorage());
    biometrics = FakeBiometrics();
    repository = FakeAuthRepository(storage);
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        biometricAuthProvider.overrideWithValue(biometrics),
        authRepositoryProvider.overrideWithValue(repository),
        dashboardRepositoryProvider.overrideWithValue(
          PreviewDashboardRepository(),
        ),
        checklistRepositoryProvider.overrideWithValue(
          PreviewChecklistRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('saved session is not restored before biometric confirmation', () async {
    final auth = await container.read(authControllerProvider.future);
    expect(auth.isAuthenticated, false);
    expect(auth.biometricLogin, true);
    expect(repository.meCalls, 0);
    await container.read(authControllerProvider.notifier).loginWithBiometrics();
    expect(container.read(authControllerProvider).value!.isAuthenticated, true);
    expect(repository.meCalls, 1);
  });

  test('cancellation preserves locked session and allows retry', () async {
    await container.read(authControllerProvider.future);
    biometrics.result = false;
    final controller = container.read(authControllerProvider.notifier);
    await controller.loginWithBiometrics();
    expect(container.read(authControllerProvider).value!.biometricLogin, true);
    expect(repository.meCalls, 0);
    expect(await storage.readAccessToken(), 'saved-access');
    biometrics.result = true;
    await controller.loginWithBiometrics();
    expect(container.read(authControllerProvider).value!.isAuthenticated, true);
  });

  test('network failure keeps session locked for another attempt', () async {
    await container.read(authControllerProvider.future);
    repository.error = const ApiException(message: 'Нет сети', offline: true);
    await expectLater(
      container.read(authControllerProvider.notifier).loginWithBiometrics(),
      throwsA(isA<ApiException>()),
    );
    expect(
      container.read(authControllerProvider).value!.isAuthenticated,
      false,
    );
    expect(container.read(authControllerProvider).value!.biometricLogin, true);
    expect(await storage.readAccessToken(), 'saved-access');
  });

  test('expired session removes tokens and biometric opt-in', () async {
    await container.read(authControllerProvider.future);
    repository.error = const ApiException(
      message: 'Сессия истекла',
      statusCode: 401,
    );
    await expectLater(
      container.read(authControllerProvider.notifier).loginWithBiometrics(),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(authControllerProvider).value!.biometricLogin, false);
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.isBiometricEnabled(), false);
  });

  test('password login resets previous account biometric opt-in', () async {
    await container.read(authControllerProvider.future);
    repository.loginUser = const UserProfile(
      id: 2,
      email: 'other@example.com',
      fullName: 'Другой',
    );
    await container
        .read(authControllerProvider.notifier)
        .login('other@example.com', 'password');
    expect(container.read(authControllerProvider).value!.isAuthenticated, true);
    expect(await storage.isBiometricEnabled(), false);
    expect(await storage.readRefreshToken(), isNull);
  });

  test(
    'password fallback for the same account preserves Face ID across restart',
    () async {
      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login('test@example.com', 'password');
      expect(await storage.isBiometricEnabled(), true);
      expect(
        container.read(authControllerProvider).value!.biometricOffer,
        isNull,
      );
      container.invalidate(authControllerProvider);
      final restarted = await container.read(authControllerProvider.future);
      expect(restarted.biometricLogin, true);
      expect(restarted.isAuthenticated, false);
      expect(repository.meCalls, 0);
    },
  );

  test('password login offers biometrics again until enabled', () async {
    await storage.clear();
    await container.read(authControllerProvider.future);
    final controller = container.read(authControllerProvider.notifier);
    await controller.login('test@example.com', 'password');
    expect(
      container.read(authControllerProvider).value!.biometricOffer,
      'Face ID',
    );
    await controller.dismissBiometricOffer();
    await controller.logout();
    await controller.login('test@example.com', 'password');
    expect(
      container.read(authControllerProvider).value!.biometricOffer,
      'Face ID',
    );
    expect(await storage.isBiometricEnabled(), false);
  });

  test(
    'locking retains session and allows Face ID without password login',
    () async {
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      await controller.loginWithBiometrics();
      await controller.lock();
      expect(
        container.read(authControllerProvider).value!.biometricLogin,
        true,
      );
      expect(await storage.readAccessToken(), 'saved-access');
      expect(await storage.isBiometricEnabled(), true);
      await controller.loginWithBiometrics();
      expect(
        container.read(authControllerProvider).value!.isAuthenticated,
        true,
      );
      expect(repository.loginCalls, 0);
    },
  );

  testWidgets(
    'startup automatically invokes Face ID once and cancellation allows retry',
    (tester) async {
      biometrics.result = false;
      await container.read(authControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(biometrics.calls, 1);
      expect(repository.meCalls, 0);
      expect(find.text('Войти с Face ID'), findsOneWidget);
      biometrics.result = true;
      await tester.tap(find.text('Войти с Face ID'));
      await tester.pumpAndSettle();
      expect(biometrics.calls, 2);
      expect(
        container.read(authControllerProvider).value!.isAuthenticated,
        true,
      );
    },
  );

  testWidgets(
    'successful Face ID enters app without showing password or calling password login',
    (tester) async {
      biometrics.pending = Completer<bool>();
      await container.read(authControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SelfCheckApp(),
        ),
      );
      await tester.pump();
      expect(biometrics.calls, 1);
      expect(find.byType(TextField), findsNothing);
      expect(repository.loginCalls, 0);
      expect(repository.meCalls, 0);
      biometrics.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Дашборд'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(repository.meCalls, 1);
      expect(repository.loginCalls, 0);
    },
  );

  testWidgets(
    'network error after Face ID offers retry without password form',
    (tester) async {
      repository.error = const ApiException(message: 'Нет сети', offline: true);
      await container.read(authControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Нет сети'), findsOneWidget);
      expect(find.text('Войти с Face ID'), findsOneWidget);
      repository.error = null;
      await tester.tap(find.text('Войти с Face ID'));
      await tester.pumpAndSettle();
      expect(
        container.read(authControllerProvider).value!.isAuthenticated,
        true,
      );
      expect(repository.loginCalls, 0);
    },
  );

  testWidgets(
    'password login offers Face ID and a new app instance restores it without password',
    (tester) async {
      await storage.clear();
      await container.read(authControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SelfCheckApp(),
        ),
      );
      await container
          .read(authControllerProvider.notifier)
          .login('test@example.com', 'password');
      await tester.pumpAndSettle();
      expect(find.text('Использовать Face ID?'), findsOneWidget);
      expect(await storage.isBiometricEnabled(), false);
      await tester.tap(find.text('Включить'));
      await tester.pumpAndSettle();
      expect(await storage.isBiometricEnabled(), true);
      expect(await storage.readBiometricAccount(), '1');
      expect(biometrics.calls, 1);
      expect(find.text('Использовать Face ID?'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final restarted = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          biometricAuthProvider.overrideWithValue(biometrics),
          authRepositoryProvider.overrideWithValue(repository),
          dashboardRepositoryProvider.overrideWithValue(
            PreviewDashboardRepository(),
          ),
          checklistRepositoryProvider.overrideWithValue(
            PreviewChecklistRepository(),
          ),
        ],
      );
      addTearDown(restarted.dispose);
      expect(
        (await restarted.read(authControllerProvider.future)).biometricLogin,
        true,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restarted,
          child: const SelfCheckApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(biometrics.calls, 2);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Дашборд'), findsWidgets);
      expect(repository.loginCalls, 1);
    },
  );

  test(
    'enabling needs biometric confirmation and logout clears preference',
    () async {
      await storage.setBiometricEnabled(false);
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      biometrics.result = false;
      expect(await controller.setBiometricEnabled(true), false);
      expect(await storage.isBiometricEnabled(), false);
      biometrics.result = true;
      expect(await controller.setBiometricEnabled(true), true);
      expect(await storage.isBiometricEnabled(), true);
      await controller.logout();
      expect(await storage.isBiometricEnabled(), false);
      expect(await storage.readAccessToken(), isNull);
    },
  );

  test('unsupported platforms retain normal session restoration', () async {
    biometrics.platformSupported = false;
    final auth = await container.read(authControllerProvider.future);
    expect(auth.isAuthenticated, true);
    expect(repository.meCalls, 1);
  });
}

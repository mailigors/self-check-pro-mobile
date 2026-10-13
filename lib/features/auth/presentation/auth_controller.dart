import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/security/biometric_auth.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository_impl.dart';
import '../domain/user_profile.dart';

class AuthState {
  const AuthState({
    this.user,
    this.biometricLogin = false,
    this.biometricOffer,
  });

  final UserProfile? user;
  final bool biometricLogin;
  final String? biometricOffer;
  bool get isAuthenticated => user != null;
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    try {
      final token = await ref.read(tokenStorageProvider).readAccessToken();
      if (token == null || token.isEmpty) return const AuthState();
      if (ref.read(biometricAuthProvider).supported &&
          await ref.read(tokenStorageProvider).isBiometricEnabled()) {
        return const AuthState(biometricLogin: true);
      }
      final user = await ref.read(authRepositoryProvider).me();
      return AuthState(user: user);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await ref.read(tokenStorageProvider).clear();
      }
      return const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(tokenStorageProvider);
      final enabled = await storage.isBiometricEnabled();
      final account = await storage.readBiometricAccount();
      final user = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      // Keep the setting for the same verified account, never transfer it.
      if (enabled && account != '${user.id}') {
        await storage.setBiometricEnabled(false);
      }
      ref.invalidate(biometricSettingsProvider);
      String? offer;
      if (ref.read(biometricAuthProvider).supported &&
          !await storage.isBiometricEnabled()) {
        offer = await ref.read(biometricAuthProvider).availableLabel();
      }
      return AuthState(user: user, biometricOffer: offer);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> loginWithBiometrics() async {
    if (state.isLoading || state.valueOrNull?.biometricLogin != true) return;
    const locked = AuthState(biometricLogin: true);
    state = const AsyncLoading();
    try {
      if (!await ref.read(biometricAuthProvider).authenticate()) {
        state = const AsyncData(locked);
        return;
      }
      final user = await ref.read(authRepositoryProvider).me();
      await ref.read(tokenStorageProvider).bindBiometricAccount(user.id);
      state = AsyncData(AuthState(user: user));
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await ref.read(tokenStorageProvider).clear();
        ref.invalidate(biometricSettingsProvider);
        state = const AsyncData(AuthState());
      } else {
        state = const AsyncData(locked);
      }
      rethrow;
    }
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    if (state.valueOrNull?.isAuthenticated != true) return false;
    if (enabled && !await ref.read(biometricAuthProvider).authenticate()) {
      return false;
    }
    final storage = ref.read(tokenStorageProvider);
    if (enabled) {
      final user = state.valueOrNull!.user!;
      await storage.bindBiometricAccount(user.id);
      await storage.setBiometricEnabled(true);
      if (!await storage.isBiometricEnabled() ||
          await storage.readBiometricAccount() != '${user.id}' ||
          (await storage.readAccessToken())?.isNotEmpty != true) {
        await storage.setBiometricEnabled(false);
        throw const ApiException(
          message: 'Не удалось сохранить вход с Face ID. Попробуйте включить его ещё раз.',
        );
      }
      await dismissBiometricOffer();
    } else {
      await storage.setBiometricEnabled(false);
    }
    ref.invalidate(biometricSettingsProvider);
    return true;
  }

  Future<void> dismissBiometricOffer() async {
    final current = state.valueOrNull;
    if (current?.user == null) return;
    state = AsyncData(AuthState(user: current!.user));
  }

  Future<void> lock() async {
    if (state.valueOrNull?.isAuthenticated != true ||
        !await ref.read(tokenStorageProvider).isBiometricEnabled()) {
      return;
    }
    state = const AsyncData(AuthState(biometricLogin: true));
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(biometricSettingsProvider);
    state = const AsyncData(AuthState());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../data/auth_repository_impl.dart';
import '../domain/user_profile.dart';

class AuthState {
  const AuthState({this.user});

  final UserProfile? user;
  bool get isAuthenticated => user != null;
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    try {
      final token = await ref.read(tokenStorageProvider).readAccessToken();
      if (token == null || token.isEmpty) return const AuthState();
      final user = await ref.read(authRepositoryProvider).me();
      return AuthState(user: user);
    } catch (_) {
      await ref.read(tokenStorageProvider).clear();
      return const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      return AuthState(user: user);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

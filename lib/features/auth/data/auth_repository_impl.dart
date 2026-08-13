import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/json_helpers.dart';
import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: null,
      parser: asMap,
    );
    final access = asString(tokens['accessToken']);
    if (access == null) {
      throw Exception('Сервер не вернул токен');
    }
    await _storage.saveTokens(
      access: access,
      refresh: asString(tokens['refreshToken']),
    );
    return me();
  }

  @override
  Future<UserProfile> me() {
    return _api.get('/users/me', parser: (data) => UserProfile.fromJson(asMap(data)));
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post<void>('/auth/logout', parser: (_) {});
    } catch (_) {
      // Local logout still happens.
    } finally {
      await _storage.clear();
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _api.post<void>(
      '/auth/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      parser: (_) {},
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

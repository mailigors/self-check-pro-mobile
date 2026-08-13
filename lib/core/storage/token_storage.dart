import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';

  Future<String?> readAccessToken() => _storage.read(key: _access);
  Future<String?> readRefreshToken() => _storage.read(key: _refresh);

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _access, value: access);
    if (refresh != null) {
      await _storage.write(key: _refresh, value: refresh);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});

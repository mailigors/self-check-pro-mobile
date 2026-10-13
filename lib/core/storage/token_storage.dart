import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _biometric = 'biometric_login_enabled';
  static const _biometricAccount = 'biometric_account_id';

  Future<String?> readBiometricAccount() =>
      _storage.read(key: _biometricAccount);
  Future<void> bindBiometricAccount(int id) =>
      _storage.write(key: _biometricAccount, value: '$id');

  Future<bool> isBiometricEnabled() async =>
      await _storage.read(key: _biometric) == 'true';

  Future<void> setBiometricEnabled(bool enabled) => enabled
      ? _storage.write(key: _biometric, value: 'true')
      : _storage.delete(key: _biometric);

  Future<String?> readAccessToken() => _storage.read(key: _access);
  Future<String?> readRefreshToken() => _storage.read(key: _refresh);

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _access, value: access);
    if (refresh != null) {
      await _storage.write(key: _refresh, value: refresh);
    } else {
      await _storage.delete(key: _refresh);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _biometric);
    await _storage.delete(key: _biometricAccount);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      webOptions: WebOptions(
        dbName: 'self_check_pro',
        publicKey: 'selfCheckProKey',
      ),
    ),
  );
});

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../network/api_exception.dart';
import '../storage/token_storage.dart';

class BiometricAuth {
  BiometricAuth(this._auth);

  final LocalAuthentication _auth;

  // Face ID and Touch ID are available in the native iOS app only.
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<String?> availableLabel() async {
    if (!supported) return null;
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Touch ID';
    } on LocalAuthException {
      return null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
    return null;
  }

  Future<bool> authenticate() async {
    if (!supported) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Подтвердите вход в Self-Check Pro',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled) {
        return false;
      }
      throw const ApiException(
        message: 'Биометрия недоступна. Войдите по логину и паролю или проверьте настройки устройства.',
      );
    } on PlatformException {
      throw const ApiException(
        message: 'Не удалось запустить биометрию. Войдите по логину и паролю.',
      );
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => BiometricAuth(LocalAuthentication()),
);

final biometricSettingsProvider =
    FutureProvider<({String? label, bool enabled})>((ref) async {
      final auth = ref.watch(biometricAuthProvider);
      if (!auth.supported) return (label: null, enabled: false);
      return (
        label: await auth.availableLabel(),
        enabled: await ref.watch(tokenStorageProvider).isBiometricEnabled(),
      );
    });

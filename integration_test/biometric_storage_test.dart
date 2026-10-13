import 'package:checklist_flutter/core/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run twice on the same iOS device: first with BIOMETRIC_STORAGE_PHASE=seed,
// then with BIOMETRIC_STORAGE_PHASE=verify. The second process must read the
// first process's Keychain entries. No user credentials or production keys.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('biometric session persists across native app launches', (
    tester,
  ) async {
    final storage = TokenStorage(
      const FlutterSecureStorage(
        iOptions: IOSOptions(accountName: 'selfcheck_biometric_storage_test'),
      ),
    );
    const phase = String.fromEnvironment('BIOMETRIC_STORAGE_PHASE');
    expect(['seed', 'verify'], contains(phase));
    if (phase == 'seed') {
      await storage.clear();
      await storage.saveTokens(
        access: 'integration-access',
        refresh: 'integration-refresh',
      );
      await storage.bindBiometricAccount(123);
      await storage.setBiometricEnabled(true);
    }
    expect(await storage.readAccessToken(), 'integration-access');
    expect(await storage.readRefreshToken(), 'integration-refresh');
    expect(await storage.readBiometricAccount(), '123');
    expect(await storage.isBiometricEnabled(), true);
    if (phase == 'verify') await storage.clear();
  });
}

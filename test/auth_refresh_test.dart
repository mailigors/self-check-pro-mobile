import 'dart:typed_data';

import 'package:checklist_flutter/core/network/api_client.dart';
import 'package:checklist_flutter/core/network/api_exception.dart';
import 'package:checklist_flutter/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class RefreshAdapter implements HttpClientAdapter {
  bool offline = true;
  int refreshStatus = 200;
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      if (offline) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return ResponseBody.fromString(
        '{"accessToken":"new-access","refreshToken":"new-refresh"}',
        refreshStatus,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      options.headers['Authorization'] == 'Bearer new-access' ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TokenStorage storage;
  late ApiClient api;
  late RefreshAdapter adapter;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'old-access',
      'refresh_token': 'old-refresh',
      'biometric_login_enabled': 'true',
      'biometric_account_id': '1',
    });
    storage = TokenStorage(const FlutterSecureStorage());
    api = ApiClient(storage);
    adapter = RefreshAdapter();
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.close());
  });

  test(
    'offline refresh retains Face ID and tokens; next attempt restores session',
    () async {
      await expectLater(
        api.get<dynamic>('/users/me'),
        throwsA(
          isA<ApiException>().having((error) => error.offline, 'offline', true),
        ),
      );
      expect(await storage.readAccessToken(), 'old-access');
      expect(await storage.readRefreshToken(), 'old-refresh');
      expect(await storage.isBiometricEnabled(), true);
      adapter.offline = false;
      await api.get<dynamic>('/users/me');
      expect(await storage.readAccessToken(), 'new-access');
      expect(await storage.isBiometricEnabled(), true);
      expect(adapter.refreshCalls, 2);
    },
  );

  test('revoked refresh token removes session', () async {
    adapter.offline = false;
    adapter.refreshStatus = 401;
    await expectLater(
      api.get<dynamic>('/users/me'),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.isBiometricEnabled(), false);
  });
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:checklist_flutter/core/config/api_config.dart';
import 'package:checklist_flutter/core/network/api_transport.dart';

// Live, unauthenticated check of routing and certificate verification.
Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (_) => true,
    ),
  );
  configureApiTransport(dio);
  try {
    final response = await dio.get<Object>('${ApiConfig.baseUrl}/users/me');
    if (response.statusCode != 401) {
      throw StateError(
        'Expected unauthenticated HTTP 401, got ${response.statusCode}',
      );
    }
    stdout.writeln('Direct backend transport: HTTP 401, TLS verification passed.');
    try {
      await dio.get<Object>('https://${ApiConfig.backendIp}/api/v1/users/me');
      throw StateError(
        'A certificate with a mismatched hostname was accepted.',
      );
    } on DioException catch (error) {
      if (!error.toString().contains('CERTIFICATE_VERIFY_FAILED')) rethrow;
      stdout.writeln('Mismatched certificate rejected.');
    }
  } finally {
    dio.close(force: true);
  }
}

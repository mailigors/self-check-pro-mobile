import 'package:flutter/foundation.dart';

class ApiConfig {
  static const backendOrigin = 'http://192.168.0.161:3002';
  static const proxyPort = 3001;
  static const apiPath = '/api/v1';

  /// На web браузер ходит в локальный CORS-прокси на том же хосте.
  /// На мобильных платформах запросы идут на API напрямую.
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
      return '$scheme://$host:$proxyPort$apiPath';
    }
    return '$backendOrigin$apiPath';
  }

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const maxUploadBytes = 10 * 1024 * 1024;
}

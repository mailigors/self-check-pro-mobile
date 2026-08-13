class ApiConfig {
  static const baseUrl = 'http://192.168.0.161:3002/api/v1';
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const maxUploadBytes = 10 * 1024 * 1024;
}

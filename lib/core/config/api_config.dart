class ApiConfig {
  static const backendOrigin = 'http://185.108.211.9:3002';
  static const apiPath = '/api/v1';
  static const baseUrl = '$backendOrigin$apiPath';

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const maxUploadBytes = 10 * 1024 * 1024;
}

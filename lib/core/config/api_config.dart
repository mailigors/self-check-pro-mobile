class ApiConfig {
  static const backendOrigin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'https://185.108.211.9',
  );
  static const apiPath = '/api/v1';
  static const baseUrl = '$backendOrigin$apiPath';

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const maxUploadBytes = 10 * 1024 * 1024;
}

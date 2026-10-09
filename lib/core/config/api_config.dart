class ApiConfig {
  static const backendOrigin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'https://selfcheck.pro',
  );
  static const apiPath = '/api/v1';
  static const baseUrl = '$backendOrigin$apiPath';
  static const backendIp = '188.242.121.224';
  static const backendTlsHost = 'selfcheck.pro';

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const maxUploadBytes = 10 * 1024 * 1024;
}

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import '../utils/json_helpers.dart';
import 'api_exception.dart';

class DownloadedFile {
  const DownloadedFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class ApiClient {
  ApiClient(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['skipAuth'] == true;
          if (!skipAuth) {
            final token = await _storage.readAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final isRefreshCall = error.requestOptions.path.contains('/auth/refresh');
          final skipAuth = error.requestOptions.extra['skipAuth'] == true;
          if (status == 401 && !skipAuth && !isRefreshCall) {
            try {
              await _refreshTokens();
              final token = await _storage.readAccessToken();
              final request = error.requestOptions;
              request.headers['Authorization'] = 'Bearer $token';
              final retry = await dio.fetch(request);
              handler.resolve(retry);
              return;
            } catch (_) {
              await _storage.clear();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _storage;
  late final Dio dio;
  Future<void>? _refreshing;

  Future<void> _refreshTokens() {
    return _refreshing ??= () async {
      try {
        final refresh = await _storage.readRefreshToken();
        if (refresh == null || refresh.isEmpty) {
          throw const ApiException(message: 'Сессия истекла', statusCode: 401);
        }
        final response = await dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refresh},
          options: Options(extra: {'skipAuth': true}),
        );
        final data = asMap(response.data);
        final access = asString(data['accessToken']);
        if (access == null) {
          throw const ApiException(message: 'Сессия истекла', statusCode: 401);
        }
        await _storage.saveTokens(
          access: access,
          refresh: asString(data['refreshToken']) ?? refresh,
        );
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) {
    return _run(() => dio.get<dynamic>(path, queryParameters: query), parser);
  }

  Future<DownloadedFile> download(String path, {String? fallbackFilename}) async {
    try {
      final response = await dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final raw = response.data;
      final bytes = raw is Uint8List
          ? raw
          : Uint8List.fromList(raw ?? const <int>[]);
      if (bytes.isEmpty) {
        throw const ApiException(message: 'Файл пуст');
      }
      final headerName = parseContentDispositionFilename(
        response.headers.value('content-disposition'),
      );
      final mime = (response.headers.value(Headers.contentTypeHeader) ??
              'application/octet-stream')
          .split(';')
          .first
          .trim();
      return DownloadedFile(
        bytes: bytes,
        filename: _filenameWithExtension(
          sanitizeFilename(headerName ?? fallbackFilename ?? 'download'),
          fallbackFilename,
        ),
        mimeType: mime,
      );
    } on DioException catch (error) {
      throw _mapDio(error);
    }
  }

  String _filenameWithExtension(String name, String? fallback) {
    if (name.contains('.')) return name;
    final fallbackExt = fallback != null && fallback.contains('.')
        ? fallback.substring(fallback.lastIndexOf('.'))
        : '';
    return '$name$fallbackExt';
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
    T Function(dynamic data)? parser,
  }) {
    return _run(
      () => dio.post<dynamic>(path, data: data, queryParameters: query, options: options),
      parser,
    );
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    T Function(dynamic data)? parser,
  }) {
    return _run(() => dio.put<dynamic>(path, data: data), parser);
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    T Function(dynamic data)? parser,
  }) {
    return _run(() => dio.patch<dynamic>(path, data: data), parser);
  }

  Future<T> _run<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data)? parser,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (parser != null) return parser(data);
      return data as T;
    } on DioException catch (error) {
      throw _mapDio(error);
    }
  }

  ApiException _mapDio(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.unknown) {
      return const ApiException(
        message: 'Нет соединения с сервером',
        offline: true,
      );
    }
    final status = error.response?.statusCode;
    final message = extractMessage(error.response?.data);
    if (status == 401 && error.requestOptions.path.contains('/auth/login')) {
      return ApiException(
        message: 'Неверно указаны имя пользователя или пароль',
        statusCode: status,
      );
    }
    return ApiException.fromStatus(status, message);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});

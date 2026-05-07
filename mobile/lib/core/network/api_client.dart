import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env.dart';
import '../storage/auth_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(_AuthInterceptor(dio: dio, storage: ref.read(authStorageProvider)));

  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: false,
      requestBody: true,
      responseBody: false,
      responseHeader: false,
      compact: true,
    ),
  );

  return dio;
});

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required this.dio, required this.storage});

  final Dio dio;
  final AuthStorage storage;

  static const _publicPaths = {'/auth/register', '/auth/login', '/auth/refresh', '/health'};

  bool _isPublic(String path) => _publicPaths.any(path.endsWith);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final token = await storage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCall = err.requestOptions.path.endsWith('/auth/refresh');
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (!isUnauthorized || isRefreshCall || alreadyRetried) {
      return handler.next(err);
    }

    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) {
      return handler.next(err);
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final access = response.data!['access_token'] as String;
      final refresh = response.data!['refresh_token'] as String;
      await storage.writeTokens(accessToken: access, refreshToken: refresh);

      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $access'
        ..extra['retried'] = true;
      final retryResponse = await dio.fetch<dynamic>(retryOptions);
      return handler.resolve(retryResponse);
    } on DioException {
      await storage.clear();
      return handler.next(err);
    }
  }
}

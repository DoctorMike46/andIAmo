import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<UserOut> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      },
    );
    return UserOut.fromJson(response.data!);
  }

  Future<TokenPair> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return TokenPair.fromJson(response.data!);
  }

  Future<TokenPair> refresh({required String refreshToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return TokenPair.fromJson(response.data!);
  }

  Future<UserOut> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    return UserOut.fromJson(response.data!);
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

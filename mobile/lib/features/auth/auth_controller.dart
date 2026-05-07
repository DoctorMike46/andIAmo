import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/auth_storage.dart';
import 'data/auth_api.dart';
import 'data/auth_models.dart';

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

class AuthLoggedIn extends AuthState {
  const AuthLoggedIn(this.user);
  final UserOut user;
}

class AuthController extends Notifier<AuthState> {
  late final AuthStorage _storage;
  late final AuthApi _api;

  @override
  AuthState build() {
    _storage = ref.read(authStorageProvider);
    _api = ref.read(authApiProvider);
    Future.microtask(_bootstrap);
    return const AuthUnknown();
  }

  Future<void> _bootstrap() async {
    final token = await _storage.readAccessToken();
    if (token == null) {
      state = const AuthLoggedOut();
      return;
    }
    try {
      final user = await _api.me();
      state = AuthLoggedIn(user);
    } on DioException {
      await _storage.clear();
      state = const AuthLoggedOut();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await _api.login(email: email, password: password);
    await _storage.writeTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    final user = await _api.me();
    state = AuthLoggedIn(user);
  }

  Future<void> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _api.register(email: email, password: password, fullName: fullName);
    await login(email: email, password: password);
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthLoggedOut();
  }

  Future<void> refreshUser() async {
    final user = await _api.me();
    state = AuthLoggedIn(user);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

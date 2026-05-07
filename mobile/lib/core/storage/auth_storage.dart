import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccessTokenKey = 'auth.access_token';
const _kRefreshTokenKey = 'auth.refresh_token';

class AuthStorage {
  AuthStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() => _storage.read(key: _kAccessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshTokenKey);

  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessTokenKey, value: accessToken);
    await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
  }
}

final authStorageProvider = Provider<AuthStorage>((ref) {
  return AuthStorage(const FlutterSecureStorage());
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ConsentSnapshot {
  const ConsentSnapshot({
    required this.purpose,
    required this.granted,
    required this.version,
  });
  final String purpose;
  final bool granted;
  final String version;

  factory ConsentSnapshot.fromJson(Map<String, dynamic> json) {
    return ConsentSnapshot(
      purpose: json['purpose'] as String,
      granted: json['granted'] as bool,
      version: json['version'] as String,
    );
  }
}

class ProfileApi {
  ProfileApi(this._dio);
  final Dio _dio;

  Future<List<ConsentSnapshot>> listConsents() async {
    final response = await _dio.get<List<dynamic>>('/me/consents');
    return response.data!
        .map((e) => ConsentSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setConsent({required String purpose, required bool granted}) async {
    await _dio.post<Map<String, dynamic>>(
      '/me/consents',
      data: {'purpose': purpose, 'granted': granted, 'version': '1.0'},
    );
  }

  Future<Map<String, dynamic>> exportData() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/export');
    return response.data!;
  }

  Future<void> deleteAccount() async {
    await _dio.delete<void>('/me');
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(dioProvider));
});

final consentsProvider =
    FutureProvider.autoDispose<List<ConsentSnapshot>>((ref) async {
  return ref.watch(profileApiProvider).listConsents();
});

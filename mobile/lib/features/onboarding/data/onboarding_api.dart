import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class PreferencesPayload {
  const PreferencesPayload({
    required this.cuisines,
    required this.moods,
    required this.dietary,
    required this.avoidTypes,
    required this.budgetMax,
    required this.maxDistanceKm,
  });

  final List<String> cuisines;
  final List<String> moods;
  final List<String> dietary;
  final List<String> avoidTypes;
  final int budgetMax;
  final double maxDistanceKm;

  Map<String, dynamic> toJson() => {
        'cuisines': cuisines,
        'moods': moods,
        'dietary': dietary,
        'avoid_types': avoidTypes,
        'budget_max': budgetMax,
        'max_distance_km': maxDistanceKm,
      };
}

class OnboardingApi {
  OnboardingApi(this._dio);
  final Dio _dio;

  Future<void> recordConsent({
    required String purpose,
    required bool granted,
    String version = '1.0',
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/me/consents',
      data: {'purpose': purpose, 'granted': granted, 'version': version},
    );
  }

  Future<void> savePreferences(PreferencesPayload payload) async {
    await _dio.put<Map<String, dynamic>>(
      '/me/preferences',
      data: payload.toJson(),
    );
  }
}

final onboardingApiProvider = Provider<OnboardingApi>((ref) {
  return OnboardingApi(ref.watch(dioProvider));
});

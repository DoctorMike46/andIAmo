import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class Preferences {
  const Preferences({
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

  factory Preferences.fromJson(Map<String, dynamic> json) {
    return Preferences(
      cuisines: (json['cuisines'] as List<dynamic>? ?? []).cast<String>(),
      moods: (json['moods'] as List<dynamic>? ?? []).cast<String>(),
      dietary: (json['dietary'] as List<dynamic>? ?? []).cast<String>(),
      avoidTypes: (json['avoid_types'] as List<dynamic>? ?? []).cast<String>(),
      budgetMax: json['budget_max'] as int,
      maxDistanceKm: (json['max_distance_km'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cuisines': cuisines,
        'moods': moods,
        'dietary': dietary,
        'avoid_types': avoidTypes,
        'budget_max': budgetMax,
        'max_distance_km': maxDistanceKm,
      };

  Preferences copyWith({
    List<String>? cuisines,
    List<String>? moods,
    List<String>? dietary,
    List<String>? avoidTypes,
    int? budgetMax,
    double? maxDistanceKm,
  }) {
    return Preferences(
      cuisines: cuisines ?? this.cuisines,
      moods: moods ?? this.moods,
      dietary: dietary ?? this.dietary,
      avoidTypes: avoidTypes ?? this.avoidTypes,
      budgetMax: budgetMax ?? this.budgetMax,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    );
  }
}

class PreferencesApi {
  PreferencesApi(this._dio);
  final Dio _dio;

  Future<Preferences> get() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/preferences');
    return Preferences.fromJson(response.data!);
  }

  Future<Preferences> update(Preferences prefs) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/me/preferences',
      data: prefs.toJson(),
    );
    return Preferences.fromJson(response.data!);
  }
}

final preferencesApiProvider = Provider<PreferencesApi>((ref) {
  return PreferencesApi(ref.watch(dioProvider));
});

final myPreferencesProvider = FutureProvider.autoDispose<Preferences>((ref) async {
  return ref.watch(preferencesApiProvider).get();
});

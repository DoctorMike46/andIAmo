import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import 'recommendation_models.dart';

class RecommendationsApi {
  RecommendationsApi(this._dio);
  final Dio _dio;

  Future<List<Recommendation>> tonight({
    double? lat,
    double? lng,
    int limit = 20,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/recommendations/tonight',
      queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'limit': limit,
      },
    );
    return response.data!
        .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final recommendationsApiProvider = Provider<RecommendationsApi>((ref) {
  return RecommendationsApi(ref.watch(dioProvider));
});

final tonightRecommendationsProvider =
    FutureProvider.autoDispose<List<Recommendation>>((ref) async {
  final api = ref.watch(recommendationsApiProvider);
  final pos = await ref.watch(currentLocationProvider.future);
  return api.tonight(lat: pos.lat, lng: pos.lng);
});

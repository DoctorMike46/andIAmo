import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'locale_models.dart';

class LocalesApi {
  LocalesApi(this._dio);

  final Dio _dio;

  Future<List<LocaleSummary>> list({
    String? type,
    String? city,
    double? lat,
    double? lng,
    double? radiusKm,
    bool openNow = false,
    int limit = 50,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/locales',
      queryParameters: {
        if (type != null) 'type': type,
        if (city != null) 'city': city,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radius_km': radiusKm,
        if (openNow) 'open_now': true,
        'limit': limit,
      },
    );
    return response.data!
        .map((e) => LocaleSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LocaleDetail> get(String id, {double? lat, double? lng}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/locales/$id',
      queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return LocaleDetail.fromJson(response.data!);
  }
}

final localesApiProvider = Provider<LocalesApi>((ref) {
  return LocalesApi(ref.watch(dioProvider));
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import 'weather_models.dart';

class WeatherApi {
  WeatherApi(this._dio);
  final Dio _dio;

  Future<WeatherSnapshot?> now({required double lat, required double lng}) async {
    final response = await _dio.get<dynamic>(
      '/weather/now',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    final data = response.data;
    if (data == null) return null;
    return WeatherSnapshot.fromJson(data as Map<String, dynamic>);
  }
}

final weatherApiProvider = Provider<WeatherApi>((ref) {
  return WeatherApi(ref.watch(dioProvider));
});

final currentWeatherProvider =
    FutureProvider.autoDispose<WeatherSnapshot?>((ref) async {
  final api = ref.watch(weatherApiProvider);
  final pos = await ref.watch(currentLocationProvider.future);
  return api.now(lat: pos.lat, lng: pos.lng);
});

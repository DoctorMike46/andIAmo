import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';

class WalkingRoute {
  const WalkingRoute({
    required this.distanceM,
    required this.durationS,
    required this.points,
  });

  final double distanceM;
  final double durationS;
  final List<LatLng> points;

  factory WalkingRoute.fromJson(Map<String, dynamic> json) {
    final coords = (json['coordinates'] as List<dynamic>)
        .map((p) {
          final pair = p as List<dynamic>;
          // Server sends [lng, lat]; LatLng wants (lat, lng).
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        })
        .toList();
    return WalkingRoute(
      distanceM: (json['distance_m'] as num).toDouble(),
      durationS: (json['duration_s'] as num).toDouble(),
      points: coords,
    );
  }
}

class RoutingApi {
  RoutingApi(this._dio);
  final Dio _dio;

  Future<WalkingRoute?> walk({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final response = await _dio.get<dynamic>(
      '/routing/walk',
      queryParameters: {
        'from_lat': fromLat,
        'from_lng': fromLng,
        'to_lat': toLat,
        'to_lng': toLng,
      },
    );
    final data = response.data;
    if (data == null) return null;
    return WalkingRoute.fromJson(data as Map<String, dynamic>);
  }
}

final routingApiProvider = Provider<RoutingApi>((ref) {
  return RoutingApi(ref.watch(dioProvider));
});

/// Parameters for [walkingRouteProvider]. Tuple-like so we can autoDispose
/// per (from, to) pair without leaking past navigations.
class WalkTo {
  const WalkTo({required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is WalkTo && other.lat == lat && other.lng == lng;
  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Loads a walking route from the user's current location to a target point.
/// Returns null silently when:
/// - the user denied geolocation,
/// - OSRM is unreachable,
/// - the network call itself fails.
/// Callers should treat any of those as "no polyline" and just not draw it.
final walkingRouteProvider =
    FutureProvider.autoDispose.family<WalkingRoute?, WalkTo>((ref, to) async {
  try {
    final pos = await ref.watch(currentLocationProvider.future);
    final api = ref.watch(routingApiProvider);
    return api.walk(
      fromLat: pos.lat,
      fromLng: pos.lng,
      toLat: to.lat,
      toLng: to.lng,
    );
  } catch (_) {
    return null;
  }
});

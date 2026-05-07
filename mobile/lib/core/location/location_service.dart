import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Centro Roma — fallback usato quando la geolocalizzazione non è disponibile.
const _romaFallback = GeoPoint(41.9028, 12.4964);

class LocationService {
  /// Restituisce la posizione corrente o `null` se permesso negato/spento.
  /// Non solleva eccezioni: in caso di errore ritorna null e il chiamante
  /// usa il fallback.
  Future<GeoPoint?> currentPosition({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(timeout);
      return GeoPoint(pos.latitude, pos.longitude);
    } on Exception {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((_) => LocationService());

/// Posizione corrente con fallback automatico al centro Roma.
/// Cached per la durata della sessione (autoDispose=false).
final currentLocationProvider = FutureProvider<GeoPoint>((ref) async {
  final pos = await ref.read(locationServiceProvider).currentPosition();
  return pos ?? _romaFallback;
});

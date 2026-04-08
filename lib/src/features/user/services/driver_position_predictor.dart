import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class DriverPositionPredictor {
  static const double _maxPredictionMeters = 20.0;

  static LatLng predict({
    required LatLng lastPosition,
    required double bearingDeg,
    required double speedKmh,
    required Duration delta,
  }) {
    final speedMps = math.max(0.0, speedKmh) / 3.6;
    final distanceMeters = math.min(
      _maxPredictionMeters,
      speedMps * delta.inMilliseconds / 1000.0,
    );

    if (distanceMeters <= 0) return lastPosition;

    const earthRadius = 6371000.0;
    final bearing = bearingDeg * math.pi / 180.0;

    final lat1 = lastPosition.latitude * math.pi / 180.0;
    final lon1 = lastPosition.longitude * math.pi / 180.0;
    final angularDistance = distanceMeters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );

    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }
}

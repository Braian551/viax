import 'package:latlong2/latlong.dart';

class GpsFilter {
  static const double _minDistanceMeters = 3.0;
  static const double _maxSpeedKmh = 160.0;
  static final Distance _distance = const Distance();

  static bool shouldAccept({
    required LatLng? previous,
    required LatLng current,
    required DateTime? previousTs,
    required DateTime currentTs,
    double? speedKmh,
  }) {
    if (speedKmh != null && speedKmh > _maxSpeedKmh) {
      return false;
    }

    if (previous == null || previousTs == null) {
      return true;
    }

    final meters = _distance.as(LengthUnit.Meter, previous, current);
    if (meters < _minDistanceMeters) {
      return false;
    }

    final dtSec = currentTs.difference(previousTs).inMilliseconds / 1000.0;
    if (dtSec > 0) {
      final inferredKmh = (meters / dtSec) * 3.6;
      if (inferredKmh > _maxSpeedKmh) {
        return false;
      }
    }

    return true;
  }
}

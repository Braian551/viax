import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class DriverMarkerController {
  static double smoothBearing({
    required double current,
    required double target,
    double maxDelta = 45.0,
  }) {
    final delta = (((target - current + 540) % 360) - 180).toDouble();
    final clamped = delta.clamp(-maxDelta, maxDelta).toDouble();
    final next = (current + clamped) % 360;
    return next < 0 ? next + 360 : next;
  }

  static LatLng lerp(LatLng a, LatLng b, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * clamped,
      a.longitude + (b.longitude - a.longitude) * clamped,
    );
  }

  static double durationSecondsFromDistanceMeters(double meters) {
    final sec = (meters / 15.0).clamp(0.3, 1.5);
    return sec.toDouble();
  }

  static double distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final la1 = a.latitude * math.pi / 180.0;
    final la2 = b.latitude * math.pi / 180.0;
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}

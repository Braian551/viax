import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class RouteSnapProgressResult {
  final LatLng point;
  final int segmentIndex;
  final double distanceMeters;

  const RouteSnapProgressResult({
    required this.point,
    required this.segmentIndex,
    required this.distanceMeters,
  });
}

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

  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  static LatLng movingAverage(
    List<LatLng> points, {
    int windowSize = 5,
  }) {
    if (points.isEmpty) {
      return const LatLng(0, 0);
    }

    final start = math.max(0, points.length - windowSize);
    final window = points.sublist(start);

    var latSum = 0.0;
    var lngSum = 0.0;
    for (final point in window) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    return LatLng(latSum / window.length, lngSum / window.length);
  }

  static LatLng snapToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.length < 2) {
      return point;
    }

    LatLng? best;
    var bestDistance = double.infinity;

    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final projected = projectPointOnSegment(point, a, b);
      final distance = distanceMeters(point, projected);

      if (distance < bestDistance) {
        bestDistance = distance;
        best = projected;
      }
    }

    return best ?? point;
  }

  static RouteSnapProgressResult snapToPolylineWithProgress({
    required LatLng point,
    required List<LatLng> polyline,
    required int currentSegmentIndex,
    int lookAheadSegments = 5,
    int maxJumpAheadSegments = 20,
    double forceForwardJumpDistanceMeters = 30.0,
  }) {
    if (polyline.length < 2) {
      return RouteSnapProgressResult(
        point: point,
        segmentIndex: 0,
        distanceMeters: 0,
      );
    }

    final lastSegmentIndex = polyline.length - 2;
    final safeCurrentSegmentIndex =
        currentSegmentIndex.clamp(0, lastSegmentIndex).toInt();
    final safeLookAhead = math.max(1, lookAheadSegments);
    final primaryEnd = math.min(
      lastSegmentIndex,
      safeCurrentSegmentIndex + safeLookAhead - 1,
    );

    var best = _findClosestProjectionInRange(
      point: point,
      polyline: polyline,
      startSegment: safeCurrentSegmentIndex,
      endSegment: primaryEnd,
    );

    if (best.distanceMeters > forceForwardJumpDistanceMeters &&
        safeCurrentSegmentIndex < lastSegmentIndex) {
      final jumpSpan = math.max(safeLookAhead, maxJumpAheadSegments);
      final jumpEnd = math.min(
        lastSegmentIndex,
        safeCurrentSegmentIndex + jumpSpan - 1,
      );

      if (jumpEnd > primaryEnd) {
        final jumpBest = _findClosestProjectionInRange(
          point: point,
          polyline: polyline,
          startSegment: primaryEnd + 1,
          endSegment: jumpEnd,
        );
        if (jumpBest.distanceMeters < best.distanceMeters) {
          best = jumpBest;
        }
      }
    }

    final nextIndex = math.max(safeCurrentSegmentIndex, best.segmentIndex);
    return RouteSnapProgressResult(
      point: best.point,
      segmentIndex: nextIndex,
      distanceMeters: best.distanceMeters,
    );
  }

  static RouteSnapProgressResult _findClosestProjectionInRange({
    required LatLng point,
    required List<LatLng> polyline,
    required int startSegment,
    required int endSegment,
  }) {
    final safeStart = startSegment.clamp(0, polyline.length - 2).toInt();
    final safeEnd = endSegment.clamp(safeStart, polyline.length - 2).toInt();

    var bestPoint = point;
    var bestDistance = double.infinity;
    var bestSegment = safeStart;

    for (var i = safeStart; i <= safeEnd; i++) {
      final projected = projectPointOnSegment(point, polyline[i], polyline[i + 1]);
      final distance = distanceMeters(point, projected);

      if (distance < bestDistance) {
        bestDistance = distance;
        bestPoint = projected;
        bestSegment = i;
      }
    }

    return RouteSnapProgressResult(
      point: bestPoint,
      segmentIndex: bestSegment,
      distanceMeters: bestDistance,
    );
  }

  static LatLng projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;

    final dx = bx - ax;
    final dy = by - ay;

    if (dx == 0 && dy == 0) {
      return a;
    }

    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clampedT = t.clamp(0.0, 1.0).toDouble();

    return LatLng(ay + clampedT * dy, ax + clampedT * dx);
  }
}

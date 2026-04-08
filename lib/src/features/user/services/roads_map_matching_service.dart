import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoadsMapMatchingService {
  const RoadsMapMatchingService(this.apiKey);

  final String apiKey;

  Future<LatLng?> snapLastPoint(List<LatLng> points) async {
    if (apiKey.isEmpty || points.isEmpty) return null;

    final path = points
        .take(5)
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    final uri = Uri.https('roads.googleapis.com', '/v1/snapToRoads', {
      'path': path,
      'interpolate': 'true',
      'key': apiKey,
    });

    final res = await http.get(uri).timeout(const Duration(milliseconds: 1200));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    final pointsList = decoded['snappedPoints'];
    if (pointsList is! List || pointsList.isEmpty) return null;

    final last = pointsList.last;
    if (last is! Map<String, dynamic>) return null;
    final loc = last['location'];
    if (loc is! Map<String, dynamic>) return null;

    final lat = (loc['latitude'] as num?)?.toDouble();
    final lng = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return LatLng(lat, lng);
  }
}

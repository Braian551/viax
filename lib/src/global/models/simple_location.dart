import 'package:latlong2/latlong.dart';

/// Simple model to represent a selected location. Used by request and preview screens.
class SimpleLocation {
  final double latitude;
  final double longitude;
  final String address;

  const SimpleLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  factory SimpleLocation.fromLatLng(LatLng pos, [String address = '']) {
    return SimpleLocation(latitude: pos.latitude, longitude: pos.longitude, address: address);
  }
}

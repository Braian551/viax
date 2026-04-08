import 'simple_location.dart';

/// Normalized location object shared across pickup, destination and preview flows.
class LocationData {
  final double lat;
  final double lng;
  final String municipality;
  final String? department;
  final String? country;
  final String? placeId;
  final String sourceType; // search | map_pin | gps
  final String? address;
  final String contextType; // urban | rural
  final bool isUrban;

  const LocationData({
    required this.lat,
    required this.lng,
    required this.municipality,
    this.department,
    this.country,
    this.placeId,
    required this.sourceType,
    this.address,
    this.contextType = 'rural',
    this.isUrban = false,
  });

  SimpleLocation toSimpleLocation() {
    return SimpleLocation(
      latitude: lat,
      longitude: lng,
      address: address ?? '',
      placeId: placeId,
      municipality: municipality,
      department: department,
      country: country,
      sourceType: sourceType,
    );
  }
}

import 'package:latlong2/latlong.dart';

import 'google_places_service.dart';

class CountryAvailabilityResult {
  final bool isAllowed;
  final String? detectedCountry;

  const CountryAvailabilityResult({
    required this.isAllowed,
    this.detectedCountry,
  });
}

class CountryAvailabilityService {
  static CountryAvailabilityResult? _cachedResult;

  static Future<CountryAvailabilityResult> validateColombiaOnly({
    required LatLng position,
  }) async {
    if (_cachedResult != null) {
      return _cachedResult!;
    }

    try {
      final data = await GooglePlacesService.reverseGeocodeLocationData(
        position: position,
        sourceType: 'country_guard',
      );

      final country = data?.country?.trim();
      if (country == null || country.isEmpty) {
        // Si no logramos resolver país, evitamos falso bloqueo.
        _cachedResult = const CountryAvailabilityResult(isAllowed: true);
        return _cachedResult!;
      }

      final normalized = country.toLowerCase();
      final allowed = normalized.contains('colombia');

      _cachedResult = CountryAvailabilityResult(
        isAllowed: allowed,
        detectedCountry: country,
      );
      return _cachedResult!;
    } catch (_) {
      _cachedResult = const CountryAvailabilityResult(isAllowed: true);
      return _cachedResult!;
    }
  }

  static void clearCache() {
    _cachedResult = null;
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PhoneCountry {
  final String name;
  final String isoCode;
  final String dialCode;
  final String flag;

  const PhoneCountry({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
  });

  String get label => '$flag $name';
}

class PhoneCountryService {
  static const PhoneCountry colombia = PhoneCountry(
    name: 'Colombia',
    isoCode: 'CO',
    dialCode: '+57',
    flag: '🇨🇴',
  );

  static const List<PhoneCountry> _fallbackCountries = [
    colombia,
    PhoneCountry(
      name: 'Estados Unidos',
      isoCode: 'US',
      dialCode: '+1',
      flag: '🇺🇸',
    ),
    PhoneCountry(name: 'México', isoCode: 'MX', dialCode: '+52', flag: '🇲🇽'),
    PhoneCountry(name: 'España', isoCode: 'ES', dialCode: '+34', flag: '🇪🇸'),
    PhoneCountry(
      name: 'Argentina',
      isoCode: 'AR',
      dialCode: '+54',
      flag: '🇦🇷',
    ),
    PhoneCountry(name: 'Chile', isoCode: 'CL', dialCode: '+56', flag: '🇨🇱'),
    PhoneCountry(name: 'Perú', isoCode: 'PE', dialCode: '+51', flag: '🇵🇪'),
    PhoneCountry(
      name: 'Ecuador',
      isoCode: 'EC',
      dialCode: '+593',
      flag: '🇪🇨',
    ),
    PhoneCountry(
      name: 'Venezuela',
      isoCode: 'VE',
      dialCode: '+58',
      flag: '🇻🇪',
    ),
  ];

  static List<PhoneCountry>? _cachedCountries;
  static Future<PhoneCountry>? _suggestedCountryFuture;

  static Future<List<PhoneCountry>> loadCountries() async {
    final cached = _cachedCountries;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://restcountries.com/v3.1/all?fields=name,cca2,idd,flag',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return _fallbackCountries;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return _fallbackCountries;
      }

      final countries =
          decoded.map(_fromRestCountry).whereType<PhoneCountry>().toList()
            ..sort((a, b) {
              if (a.isoCode == colombia.isoCode) return -1;
              if (b.isoCode == colombia.isoCode) return 1;
              return a.name.compareTo(b.name);
            });

      _cachedCountries = countries.isEmpty ? _fallbackCountries : countries;
      return _cachedCountries!;
    } catch (e) {
      debugPrint('[PhoneCountryService] Error cargando países: $e');
      return _fallbackCountries;
    }
  }

  static Future<PhoneCountry> detectSuggestedCountry() {
    return _suggestedCountryFuture ??= _resolveSuggestedCountry();
  }

  static PhoneCountry? findByIsoCode(
    Iterable<PhoneCountry> countries,
    String? isoCode,
  ) {
    final normalizedCode = _normalizeIsoCode(isoCode);
    if (normalizedCode == null) return null;

    for (final country in countries) {
      if (_normalizeIsoCode(country.isoCode) == normalizedCode) {
        return country;
      }
    }

    return null;
  }

  static Future<PhoneCountry> _resolveSuggestedCountry() async {
    try {
      final countries = await loadCountries();
      final countryCode = await _detectCountryCode();
      return findByIsoCode(countries, countryCode) ?? colombia;
    } catch (e) {
      debugPrint('[PhoneCountryService] Error detectando país sugerido: $e');
      return colombia;
    }
  }

  static Future<String?> _detectCountryCode() async {
    final locationCountry = await _detectCountryCodeFromLocation();
    if (locationCountry != null) {
      return locationCountry;
    }

    return _detectCountryCodeFromLocale();
  }

  static Future<String?> _detectCountryCodeFromLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 1000,
        ),
      ).timeout(const Duration(seconds: 4));

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 4));

      if (placemarks.isEmpty) {
        return null;
      }

      return _normalizeIsoCode(placemarks.first.isoCountryCode);
    } catch (e) {
      debugPrint(
        '[PhoneCountryService] No se pudo detectar país por ubicación: $e',
      );
      return null;
    }
  }

  static String? _detectCountryCodeFromLocale() {
    for (final locale in PlatformDispatcher.instance.locales) {
      final countryCode = _normalizeIsoCode(locale.countryCode);
      if (countryCode != null) {
        return countryCode;
      }
    }

    return _normalizeIsoCode(PlatformDispatcher.instance.locale.countryCode);
  }

  static String? _normalizeIsoCode(String? isoCode) {
    final normalized = isoCode?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static PhoneCountry? _fromRestCountry(dynamic item) {
    if (item is! Map<String, dynamic>) return null;

    final nameData = item['name'];
    final iddData = item['idd'];
    final root = iddData is Map<String, dynamic>
        ? iddData['root']?.toString()
        : null;
    final suffixes = iddData is Map<String, dynamic>
        ? iddData['suffixes']
        : null;
    if (root == null || root.isEmpty || suffixes is! List || suffixes.isEmpty) {
      return null;
    }

    final commonName = nameData is Map<String, dynamic>
        ? nameData['common']?.toString()
        : null;
    final suffixValue = suffixes.isEmpty ? null : suffixes.first;
    final suffix = suffixValue?.toString() ?? '';
    final dialCode = '$root$suffix';

    if (commonName == null || commonName.isEmpty || dialCode.length < 2) {
      return null;
    }

    return PhoneCountry(
      name: commonName,
      isoCode: item['cca2']?.toString() ?? '',
      dialCode: dialCode,
      flag: item['flag']?.toString() ?? '',
    );
  }
}

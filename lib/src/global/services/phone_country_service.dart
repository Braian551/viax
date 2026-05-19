import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _deviceCountryChannel = MethodChannel(
    'com.viax.app/device_country',
  );
  static const Set<String> _sharedCallingCodeRoots = {'+1', '+7'};

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

    final deviceCountry = await _detectCountryCodeFromDeviceRegion();
    if (deviceCountry != null) {
      return deviceCountry;
    }

    return _detectCountryCodeFromLocale();
  }

  static Future<String?> _detectCountryCodeFromDeviceRegion() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final countryCode = await _deviceCountryChannel.invokeMethod<String>(
        'getPreferredCountryIso',
      );
      return _normalizeIsoCode(countryCode);
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint(
        '[PhoneCountryService] No se pudo detectar país por red o SIM: $e',
      );
      return null;
    }
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
    final isoCode = item['cca2']?.toString() ?? '';
    final iddData = item['idd'];
    final root = iddData is Map<String, dynamic>
        ? iddData['root']?.toString()
        : null;
    final suffixes = iddData is Map<String, dynamic>
        ? iddData['suffixes']
        : null;
    if (root == null || root.isEmpty || isoCode.isEmpty) {
      return null;
    }

    final commonName = nameData is Map<String, dynamic>
        ? nameData['common']?.toString()
        : null;
    final dialCode = _buildDialCode(root: root, suffixes: suffixes);

    if (commonName == null || commonName.isEmpty || dialCode == null) {
      return null;
    }

    return PhoneCountry(
      name: commonName,
      isoCode: isoCode,
      dialCode: dialCode,
      flag: item['flag']?.toString() ?? '',
    );
  }

  static String? _buildDialCode({
    required String root,
    required dynamic suffixes,
  }) {
    if (_sharedCallingCodeRoots.contains(root)) {
      return root;
    }

    if (suffixes is! List || suffixes.isEmpty) {
      return root;
    }

    final normalizedSuffixes = suffixes
        .map((suffix) => suffix?.toString() ?? '')
        .where((suffix) => suffix.isNotEmpty)
        .toList();

    if (normalizedSuffixes.isEmpty) {
      return root;
    }

    final shortestSuffix = normalizedSuffixes.reduce(
      (left, right) => left.length <= right.length ? left : right,
    );

    return '$root$shortestSuffix';
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/network/network_request_executor.dart';

/// Servicio para obtener y cachear de forma segura las llaves API del backend.
///
/// Esto evita dejar llaves sensibles hardcodeadas en la app Flutter,
/// lo que las haría extraíbles desde el APK.
///
/// Uso:
/// ```dart
/// // Inicializar al arrancar la app (por ejemplo, en main.dart)
/// await AppSecretsService.instance.initialize();
///
/// // Acceder a las llaves desde cualquier lugar
/// final token = AppSecretsService.instance.mapboxToken;
/// ```
class AppSecretsService {
  // Instancia singleton.
  static final AppSecretsService instance = AppSecretsService._internal();
  AppSecretsService._internal();

  // Llaves API en memoria.
  String _mapboxToken = '';
  String _tomtomApiKey = '';
  String _googlePlacesApiKey = '';
  String _nominatimUserAgent = 'Viax App';
  String _nominatimEmail = '';

  // Límites de cuota.
  int _mapboxMonthlyRequestLimit = 100000;
  int _mapboxMonthlyRoutingLimit = 100000;
  int _tomtomDailyRequestLimit = 2500;

  // Estado interno.
  bool _initialized = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();
  static const Duration _cacheMaxAge = Duration(hours: 24);
  static const String _prefsMapboxToken = 'viax_secrets_mapbox_token';
  static const String _prefsTomtomApiKey = 'viax_secrets_tomtom_api_key';
  static const String _prefsGooglePlacesKey =
      'viax_secrets_google_places_key';
  static const String _prefsNominatimUserAgent =
      'viax_secrets_nominatim_user_agent';
  static const String _prefsNominatimEmail = 'viax_secrets_nominatim_email';
  static const String _prefsMapboxMonthlyRequestLimit =
      'viax_secrets_mapbox_monthly_request_limit';
  static const String _prefsMapboxMonthlyRoutingLimit =
      'viax_secrets_mapbox_monthly_routing_limit';
  static const String _prefsTomtomDailyRequestLimit =
      'viax_secrets_tomtom_daily_request_limit';
  static const String _prefsCachedAt = 'viax_secrets_cached_at';
  static const String _envMapboxToken = String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
    defaultValue: '',
  );
  static const String _envMapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  // Getters.
  String get mapboxToken {
    if (_mapboxToken.isNotEmpty) return _mapboxToken;

    final envToken = _envMapboxToken.trim();
    if (envToken.isNotEmpty) return envToken;

    final envAccessToken = _envMapboxAccessToken.trim();
    if (envAccessToken.isNotEmpty) return envAccessToken;

    final configToken = AppConfig.mapboxAccessToken.trim();
    if (configToken.isNotEmpty && configToken != 'YOUR_MAPBOX_TOKEN') {
      return configToken;
    }

    return '';
  }
  String get tomtomApiKey => _tomtomApiKey;
  String get googlePlacesApiKey => _googlePlacesApiKey;
  String get nominatimUserAgent => _nominatimUserAgent;
  String get nominatimEmail => _nominatimEmail;

  int get mapboxMonthlyRequestLimit => _mapboxMonthlyRequestLimit;
  int get mapboxMonthlyRoutingLimit => _mapboxMonthlyRoutingLimit;
  int get tomtomDailyRequestLimit => _tomtomDailyRequestLimit;

  bool get isInitialized => _initialized;

  bool get _hasAvailableSecrets =>
      mapboxToken.isNotEmpty ||
      _googlePlacesApiKey.isNotEmpty ||
      _tomtomApiKey.isNotEmpty;

  /// Inicializa el servicio con estrategia cache-first.
  ///
  /// Si hay cache válido, retorna de inmediato y refresca en background.
  /// Solo espera al backend en el primer arranque o cuando el cache expiró.
  Future<bool> initialize() async {
    if (_initialized) return true;
    if (_isLoading) return _hasAvailableSecrets;

    _isLoading = true;

    try {
      final cached = await _loadFromCache();
      if (cached) {
        _initialized = true;
        unawaited(_refreshFromBackend());
        return true;
      }

      return await _refreshFromBackend();
    } finally {
      _isLoading = false;
    }
  }

  /// Fuerza una actualización de las llaves API desde el backend.
  Future<void> refresh() async {
    _initialized = false;
    await _refreshFromBackend();
  }

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAtMillis = prefs.getInt(_prefsCachedAt);

      if (cachedAtMillis == null) {
        return false;
      }

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMillis);
      final cacheAge = DateTime.now().difference(cachedAt);

      if (cacheAge > _cacheMaxAge) {
        debugPrint('AppSecretsService: cache expirado, se refrescará desde backend');
        return false;
      }

      final cachedMapboxToken = prefs.getString(_prefsMapboxToken) ?? '';
      final cachedGooglePlacesKey =
          prefs.getString(_prefsGooglePlacesKey) ?? '';

      if (cachedMapboxToken.isEmpty && cachedGooglePlacesKey.isEmpty) {
        return false;
      }

      _mapboxToken = cachedMapboxToken;
      _tomtomApiKey = prefs.getString(_prefsTomtomApiKey) ?? _tomtomApiKey;
      _googlePlacesApiKey = cachedGooglePlacesKey;
      _nominatimUserAgent =
          prefs.getString(_prefsNominatimUserAgent) ?? _nominatimUserAgent;
      _nominatimEmail =
          prefs.getString(_prefsNominatimEmail) ?? _nominatimEmail;

      _mapboxMonthlyRequestLimit =
          prefs.getInt(_prefsMapboxMonthlyRequestLimit) ??
          _mapboxMonthlyRequestLimit;
      _mapboxMonthlyRoutingLimit =
          prefs.getInt(_prefsMapboxMonthlyRoutingLimit) ??
          _mapboxMonthlyRoutingLimit;
      _tomtomDailyRequestLimit =
          prefs.getInt(_prefsTomtomDailyRequestLimit) ??
          _tomtomDailyRequestLimit;

      debugPrint('AppSecretsService: llaves API cargadas desde cache');
      return _hasAvailableSecrets;
    } catch (e) {
      debugPrint('AppSecretsService: error cargando cache de llaves API: $e');
      return false;
    }
  }

  Future<bool> _refreshFromBackend() async {
    if (_isRefreshing) {
      return _hasAvailableSecrets;
    }

    _isRefreshing = true;

    try {
      final result = await _network.getJson(
        url: Uri.parse('${AppConfig.baseUrl}/get_api_keys.php'),
        headers: {
          'Accept': 'application/json',
        },
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        debugPrint(
          'AppSecretsService: no se pudieron cargar las llaves API: ${result.error?.userMessage}',
        );
        _initialized = _hasAvailableSecrets;
        return _initialized;
      }

      final data = result.json!;

      if (data['success'] == true && data['data'] != null) {
        final keys = data['data'];

        _mapboxToken = (keys['mapbox_public_token'] ?? '').toString();
        _tomtomApiKey = (keys['tomtom_api_key'] ?? '').toString();
        _googlePlacesApiKey =
            (keys['google_places_api_key'] ?? '').toString();
        _nominatimUserAgent =
            (keys['nominatim_user_agent'] ?? 'Viax App').toString();
        _nominatimEmail = (keys['nominatim_email'] ?? '').toString();

        _mapboxMonthlyRequestLimit = _toInt(
          keys['mapbox_monthly_request_limit'],
          fallback: 100000,
        );
        _mapboxMonthlyRoutingLimit = _toInt(
          keys['mapbox_monthly_routing_limit'],
          fallback: 100000,
        );
        _tomtomDailyRequestLimit = _toInt(
          keys['tomtom_daily_request_limit'],
          fallback: 2500,
        );

        _initialized = _hasAvailableSecrets;
        await _saveToCache();
        debugPrint('AppSecretsService: llaves API actualizadas desde backend');
        return _initialized;
      }

      debugPrint('AppSecretsService: no se pudieron cargar las llaves API (payload inválido)');
      _initialized = _hasAvailableSecrets;
      return _initialized;
    } catch (e) {
      debugPrint('AppSecretsService: error cargando llaves API: $e');
      _initialized = _hasAvailableSecrets;
      return _initialized;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_prefsMapboxToken, _mapboxToken);
      await prefs.setString(_prefsTomtomApiKey, _tomtomApiKey);
      await prefs.setString(_prefsGooglePlacesKey, _googlePlacesApiKey);
      await prefs.setString(_prefsNominatimUserAgent, _nominatimUserAgent);
      await prefs.setString(_prefsNominatimEmail, _nominatimEmail);
      await prefs.setInt(
        _prefsMapboxMonthlyRequestLimit,
        _mapboxMonthlyRequestLimit,
      );
      await prefs.setInt(
        _prefsMapboxMonthlyRoutingLimit,
        _mapboxMonthlyRoutingLimit,
      );
      await prefs.setInt(_prefsTomtomDailyRequestLimit, _tomtomDailyRequestLimit);
      await prefs.setInt(
        _prefsCachedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('AppSecretsService: error guardando cache de llaves API: $e');
    }
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

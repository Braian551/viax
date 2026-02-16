import 'dart:convert';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/network/network_request_executor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to securely fetch and cache API keys from the backend.
///
/// This prevents hardcoding sensitive API keys in the Flutter app,
/// which would make them extractable from the APK.
///
/// Usage:
/// ```dart
/// // Initialize on app startup (e.g., in main.dart)
/// await AppSecretsService.instance.initialize();
///
/// // Access keys anywhere
/// final token = AppSecretsService.instance.mapboxToken;
/// ```
class AppSecretsService {
  // Singleton instance
  static final AppSecretsService instance = AppSecretsService._internal();
  AppSecretsService._internal();

  // Cached API keys
  String _mapboxToken = '';
  String _tomtomApiKey = '';
  String _googlePlacesApiKey = '';
  String _nominatimUserAgent = 'Viax App';
  String _nominatimEmail = '';

  // Quota limits
  int _mapboxMonthlyRequestLimit = 100000;
  int _mapboxMonthlyRoutingLimit = 100000;
  int _tomtomDailyRequestLimit = 2500;

  // State
  bool _initialized = false;
  bool _isLoading = false;
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();
  static const String _cachePrefix = 'app_secrets_';
  static const String _envMapboxToken = String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
    defaultValue: '',
  );
  static const String _envMapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  // Getters
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

  /// Initialize the service by fetching API keys from the backend.
  /// Should be called once during app startup.
  Future<bool> initialize() async {
    if (_initialized || _isLoading) return _initialized;

    _isLoading = true;

    try {
      await _loadCachedKeys();

      final result = await _network.getJson(
        url: Uri.parse('${AppConfig.baseUrl}/get_api_keys.php'),
        headers: {
          'Accept': 'application/json',
        },
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        print('AppSecretsService: Failed to load API keys: ${result.error?.userMessage}');
        _initialized = mapboxToken.isNotEmpty ||
            _googlePlacesApiKey.isNotEmpty ||
            _tomtomApiKey.isNotEmpty;
        return _initialized;
      }

      final data = result.json!;

      if (data['success'] == true && data['data'] != null) {
        final keys = data['data'];

        _mapboxToken = keys['mapbox_public_token'] ?? '';
        _tomtomApiKey = keys['tomtom_api_key'] ?? '';
        _googlePlacesApiKey = keys['google_places_api_key'] ?? '';
        _nominatimUserAgent = keys['nominatim_user_agent'] ?? 'Viax App';
        _nominatimEmail = keys['nominatim_email'] ?? '';

        _mapboxMonthlyRequestLimit = keys['mapbox_monthly_request_limit'] ?? 100000;
        _mapboxMonthlyRoutingLimit = keys['mapbox_monthly_routing_limit'] ?? 100000;
        _tomtomDailyRequestLimit = keys['tomtom_daily_request_limit'] ?? 2500;

        _initialized = mapboxToken.isNotEmpty ||
            _googlePlacesApiKey.isNotEmpty ||
            _tomtomApiKey.isNotEmpty;
        await _saveKeysToCache();
        print('AppSecretsService: API keys loaded successfully');
      } else {
        print('AppSecretsService: Failed to load API keys (payload invalid)');
        _initialized = mapboxToken.isNotEmpty ||
            _googlePlacesApiKey.isNotEmpty ||
            _tomtomApiKey.isNotEmpty;
      }
    } catch (e) {
      print('AppSecretsService: Error loading API keys: $e');
      _initialized = mapboxToken.isNotEmpty ||
          _googlePlacesApiKey.isNotEmpty ||
          _tomtomApiKey.isNotEmpty;
    } finally {
      _isLoading = false;
    }

    return _initialized;
  }

  /// Force refresh the API keys from the backend.
  Future<void> refresh() async {
    _initialized = false;
    await initialize();
  }

  Future<void> _loadCachedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _mapboxToken = prefs.getString('${_cachePrefix}mapbox_token') ?? _mapboxToken;
      _tomtomApiKey = prefs.getString('${_cachePrefix}tomtom_api_key') ?? _tomtomApiKey;
      _googlePlacesApiKey = prefs.getString('${_cachePrefix}google_places_api_key') ?? _googlePlacesApiKey;
      _nominatimUserAgent = prefs.getString('${_cachePrefix}nominatim_user_agent') ?? _nominatimUserAgent;
      _nominatimEmail = prefs.getString('${_cachePrefix}nominatim_email') ?? _nominatimEmail;

      _mapboxMonthlyRequestLimit = prefs.getInt('${_cachePrefix}mapbox_monthly_request_limit') ?? _mapboxMonthlyRequestLimit;
      _mapboxMonthlyRoutingLimit = prefs.getInt('${_cachePrefix}mapbox_monthly_routing_limit') ?? _mapboxMonthlyRoutingLimit;
      _tomtomDailyRequestLimit = prefs.getInt('${_cachePrefix}tomtom_daily_request_limit') ?? _tomtomDailyRequestLimit;
    } catch (e) {
      print('AppSecretsService: Error loading cached API keys: $e');
    }
  }

  Future<void> _saveKeysToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_mapboxToken.isNotEmpty) {
        await prefs.setString('${_cachePrefix}mapbox_token', _mapboxToken);
      }
      if (_tomtomApiKey.isNotEmpty) {
        await prefs.setString('${_cachePrefix}tomtom_api_key', _tomtomApiKey);
      }
      if (_googlePlacesApiKey.isNotEmpty) {
        await prefs.setString('${_cachePrefix}google_places_api_key', _googlePlacesApiKey);
      }

      await prefs.setString('${_cachePrefix}nominatim_user_agent', _nominatimUserAgent);
      await prefs.setString('${_cachePrefix}nominatim_email', _nominatimEmail);
      await prefs.setInt('${_cachePrefix}mapbox_monthly_request_limit', _mapboxMonthlyRequestLimit);
      await prefs.setInt('${_cachePrefix}mapbox_monthly_routing_limit', _mapboxMonthlyRoutingLimit);
      await prefs.setInt('${_cachePrefix}tomtom_daily_request_limit', _tomtomDailyRequestLimit);
    } catch (e) {
      print('AppSecretsService: Error caching API keys: $e');
    }
  }
}

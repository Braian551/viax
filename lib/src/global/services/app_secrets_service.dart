import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

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
  String _nominatimUserAgent = 'Viax App';
  String _nominatimEmail = '';

  // Quota limits
  int _mapboxMonthlyRequestLimit = 100000;
  int _mapboxMonthlyRoutingLimit = 100000;
  int _tomtomDailyRequestLimit = 2500;

  // State
  bool _initialized = false;
  bool _isLoading = false;

  // Getters
  String get mapboxToken => _mapboxToken;
  String get tomtomApiKey => _tomtomApiKey;
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
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/get_api_keys.php'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final keys = data['data'];

          _mapboxToken = keys['mapbox_public_token'] ?? '';
          _tomtomApiKey = keys['tomtom_api_key'] ?? '';
          _nominatimUserAgent = keys['nominatim_user_agent'] ?? 'Viax App';
          _nominatimEmail = keys['nominatim_email'] ?? '';

          _mapboxMonthlyRequestLimit = keys['mapbox_monthly_request_limit'] ?? 100000;
          _mapboxMonthlyRoutingLimit = keys['mapbox_monthly_routing_limit'] ?? 100000;
          _tomtomDailyRequestLimit = keys['tomtom_daily_request_limit'] ?? 2500;

          _initialized = true;
          print('AppSecretsService: API keys loaded successfully');
        }
      } else {
        print('AppSecretsService: Failed to load API keys (${response.statusCode})');
      }
    } catch (e) {
      print('AppSecretsService: Error loading API keys: $e');
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
}

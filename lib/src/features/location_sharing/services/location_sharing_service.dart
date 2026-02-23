import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viax/src/core/config/app_config.dart';

/// Represents an active location-sharing session.
class LocationShareSession {
  final int id;
  final String token;
  final String shareUrl;
  final String deepLink;
  final DateTime expiresAt;

  const LocationShareSession({
    required this.id,
    required this.token,
    required this.shareUrl,
    required this.deepLink,
    required this.expiresAt,
  });

  factory LocationShareSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String;
    return LocationShareSession(
      id: json['id'] as int,
      token: token,
      shareUrl: AppConfig.buildShareUrl(token),
      deepLink: AppConfig.buildDeepLink(token),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Data received when polling a shared location.
class SharedLocationData {
  final String token;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final double heading;
  final double speed;
  final double accuracy;
  final String? lastUpdate;
  final String? sharerName;
  final String? sharerPhoto;
  final String? vehiclePlate;
  final String? destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final String? expiresAt;
  final int remainingSeconds;
  final bool expired;

  const SharedLocationData({
    required this.token,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.heading = 0,
    this.speed = 0,
    this.accuracy = 0,
    this.lastUpdate,
    this.sharerName,
    this.sharerPhoto,
    this.vehiclePlate,
    this.destinationAddress,
    this.destinationLat,
    this.destinationLng,
    this.expiresAt,
    this.remainingSeconds = 0,
    this.expired = false,
  });

  factory SharedLocationData.fromJson(Map<String, dynamic> json) {
    return SharedLocationData(
      token: json['token'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      lastUpdate: json['last_update'] as String?,
      sharerName: json['sharer_name'] as String?,
      sharerPhoto: json['sharer_photo'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      destinationAddress: json['destination_address'] as String?,
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      expiresAt: json['expires_at'] as String?,
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
      expired: json['expired'] as bool? ?? false,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
}

/// Singleton service that manages location sharing.
///
/// - Creating a share session (generates token).
/// - Sending GPS updates to the backend while sharing.
/// - Polling location from the backend for viewers.
class LocationSharingService {
  LocationSharingService._();
  static final LocationSharingService instance = LocationSharingService._();

  static const String _kHandledShareTokens =
      'viax_shared_location_handled_tokens_v1';
  static const String _kDismissedShareTokens =
      'viax_shared_location_dismissed_tokens_v1';

  // ----- State -----
  LocationShareSession? _currentSession;
  Timer? _sendTimer;
  StreamSubscription<geo.Position>? _positionStream;
  bool _isSending = false;

  LocationShareSession? get currentSession => _currentSession;
  bool get isSharing => _isSending;

  // ─────────────────────────────────────────
  // DEEP LINK TOKEN GUARD (viewer side)
  // ─────────────────────────────────────────

  static Future<Set<String>> _readTokenSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? const <String>[];
    return list.toSet();
  }

  static Future<void> _writeTokenSet(String key, Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = values.take(80).toList(growable: false);
    await prefs.setStringList(key, trimmed);
  }

  static Future<bool> isTokenHandled(String token) async {
    final set = await _readTokenSet(_kHandledShareTokens);
    return set.contains(token);
  }

  static Future<bool> isTokenDismissed(String token) async {
    final set = await _readTokenSet(_kDismissedShareTokens);
    return set.contains(token);
  }

  static Future<void> markTokenHandled(String token) async {
    final set = await _readTokenSet(_kHandledShareTokens);
    set.add(token);
    await _writeTokenSet(_kHandledShareTokens, set);
  }

  static Future<void> markTokenDismissed(String token) async {
    final dismissed = await _readTokenSet(_kDismissedShareTokens);
    dismissed.add(token);
    await _writeTokenSet(_kDismissedShareTokens, dismissed);

    final handled = await _readTokenSet(_kHandledShareTokens);
    handled.add(token);
    await _writeTokenSet(_kHandledShareTokens, handled);
  }

  // ─────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────

  /// Creates a new share session on the backend and returns [LocationShareSession].
  Future<LocationShareSession> createShare({
    required int userId,
    int? solicitudId,
    int expiresMinutes = 120,
  }) async {
    final url = '${AppConfig.locationSharingUrl}/create_share.php';
    final body = jsonEncode({
      'user_id': userId,
      if (solicitudId != null) 'solicitud_id': solicitudId,
      'expires_minutes': expiresMinutes,
    });

    final response = await _postWithFallback(url, body);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Error creando sesión de compartir');
    }

    final session = LocationShareSession.fromJson(
      json['data'] as Map<String, dynamic>,
    );
    _currentSession = session;
    return session;
  }

  // ─────────────────────────────────────────
  // SEND UPDATES (sharer side)
  // ─────────────────────────────────────────

  /// Start broadcasting the device's position to the backend every 3 seconds.
  void startSendingUpdates() {
    if (_isSending || _currentSession == null) return;
    _isSending = true;

    // Listen to position stream
    _positionStream =
        geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          _pushLocation(position);
        });

    // Additionally push on a timer for reliability
    _sendTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
          ),
        );
        _pushLocation(pos);
      } catch (_) {}
    });
  }

  /// Stops broadcasting location updates.
  void stopSendingUpdates() {
    _isSending = false;
    _sendTimer?.cancel();
    _sendTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Stop sharing and notify backend.
  Future<void> stopSharing() async {
    stopSendingUpdates();
    final session = _currentSession;
    _currentSession = null;

    if (session != null) {
      await stopSharingByToken(session.token);
    }
  }

  /// Stop sharing by [token] (useful when UI still has token but service state was reset).
  Future<void> stopSharingByToken(String token) async {
    stopSendingUpdates();

    if (token.isEmpty) return;

    try {
      final url = '${AppConfig.locationSharingUrl}/stop_share.php';
      final body = jsonEncode({'token': token});
      await _postWithFallback(url, body);
    } catch (e) {
      debugPrint('[LocationSharing] Error stopping share by token: $e');
    }

    if (_currentSession?.token == token) {
      _currentSession = null;
    }
  }

  Future<void> _pushLocation(geo.Position position) async {
    final session = _currentSession;
    if (session == null) return;

    try {
      final url = '${AppConfig.locationSharingUrl}/update_location.php';
      final body = jsonEncode({
        'token': session.token,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
      });
      await _postWithFallback(url, body);
    } catch (e) {
      debugPrint('[LocationSharing] Push error: $e');
    }
  }

  // ─────────────────────────────────────────
  // GET LOCATION (viewer side)
  // ─────────────────────────────────────────

  /// Fetches the current shared location for a given [token].
  static Future<SharedLocationData?> getLocation(String token) async {
    final urls = AppConfig.allBaseUrls
        .map((base) => '$base/location_sharing/get_location.php?token=$token')
        .toList();

    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));

        final json = jsonDecode(response.body) as Map<String, dynamic>;

        if (json['success'] == true) {
          return SharedLocationData.fromJson(
            json['data'] as Map<String, dynamic>,
          );
        }

        // Handle expired/gone
        if (response.statusCode == 410) {
          final data = json['data'] as Map<String, dynamic>? ?? {};
          return SharedLocationData(
            token: token,
            isActive: false,
            expired: true,
            sharerName: data['sharer_name'] as String?,
          );
        }
      } catch (e) {
        debugPrint('[LocationSharing] getLocation error on $url: $e');
        continue;
      }
    }

    return null; // All endpoints failed
  }

  // ─────────────────────────────────────────
  // HTTP helpers
  // ─────────────────────────────────────────

  /// POST with fallback across all configured base URLs.
  Future<http.Response> _postWithFallback(
    String primaryUrl,
    String body,
  ) async {
    String? lastError;

    // Try the primary URL first
    try {
      final response = await http
          .post(
            Uri.parse(primaryUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 500) return response;
      lastError = 'HTTP ${response.statusCode}: ${response.body}';
    } catch (e) {
      lastError = e.toString();
    }

    // Fallback to other base URLs
    final pathSuffix = primaryUrl.replaceFirst(AppConfig.baseUrl, '');
    for (final base in AppConfig.allBaseUrls) {
      final fallbackUrl = '$base$pathSuffix';
      if (fallbackUrl == primaryUrl) continue;
      try {
        final response = await http
            .post(
              Uri.parse(fallbackUrl),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode < 500) {
          AppConfig.rememberWorkingBaseUrl(base);
          return response;
        }
        lastError = 'HTTP ${response.statusCode}: ${response.body}';
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw Exception(
      lastError != null
          ? 'Todos los servidores no responden. Último error: $lastError'
          : 'Todos los servidores no responden',
    );
  }
}

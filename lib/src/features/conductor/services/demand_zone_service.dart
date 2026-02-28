import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../models/demand_zone_model.dart';

/// Servicio para obtener y gestionar zonas de alta demanda
/// Similar al sistema de surge pricing de Uber/Didi
/// 
/// Proporciona información sobre áreas con alta demanda de viajes
/// para que los conductores puedan posicionarse estratégicamente
class DemandZoneService {
  static Timer? _refreshTimer;
  static bool _isRefreshing = false;
  static bool _isFetchInProgress = false;
  static List<DemandZone> _cachedZones = [];
  static DateTime? _lastUpdate;
  static DateTime? _lastFetchAt;
  static DateTime? _lastLocationUpdateAt;
  static double? _currentLatitude;
  static double? _currentLongitude;
  static int _consecutiveEmptyResponses = 0;
  static bool _locationDirty = false;
  static int _serverSuggestedRefreshSeconds = refreshIntervalSeconds;
  
  /// Intervalo de actualización en segundos
  static const int refreshIntervalSeconds = 30;
  static const int minRefreshIntervalSeconds = 12;
  static const int staleRefreshIntervalSeconds = 90;
  static const double locationChangeThresholdKm = 0.12; // 120m
  
  /// Obtener zonas de demanda cercanas a una ubicación
  static Future<DemandZonesResponse> getDemandZones({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    double zoneSizeKm = 0.5,
    bool includeDemo = false,
  }) async {
    try {
      final response = await _postWithFallback(
        path: '/conductor/get_demand_zones.php',
        body: {
          'latitud': latitude,
          'longitud': longitude,
          'radio_km': radiusKm,
          'zone_size_km': zoneSizeKm,
          'include_demo': includeDemo,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final zonesResponse = DemandZonesResponse.fromJson(data);
        
        // Actualizar caché
        _cachedZones = zonesResponse.zones;
        _lastUpdate = DateTime.now();
        
        debugPrint('🔥 ${zonesResponse.zones.length} zonas de demanda obtenidas');
        return zonesResponse;
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode}: ${response.body}');
        return DemandZonesResponse.error('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener zonas de demanda: $e');
      
      // Retornar caché si está disponible
      if (_cachedZones.isNotEmpty) {
        return DemandZonesResponse(
          success: true,
          zones: _cachedZones,
          message: 'Datos en caché',
        );
      }
      
      return DemandZonesResponse.error('Error de conexión: $e');
    }
  }

  /// Hace POST probando hosts candidatos hasta que uno responda o se agoten
  static Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Exception? lastError;

    for (final base in AppConfig.baseUrlCandidates) {
      final url = Uri.parse('$base$path');
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(timeout);

        // Recordar el host que funcionÃ³ para siguientes llamadas
        AppConfig.rememberWorkingBaseUrl(base);
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('⏳ Timeout en $path usando $base, probando siguiente host...');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('🌐 Error en $path usando $base: $e');
      }
    }

    throw lastError ?? Exception('No hay hosts disponibles para $path');
  }
  
  /// Iniciar actualización automática de zonas
  static void startAutoRefresh({
    required double latitude,
    required double longitude,
    required Function(List<DemandZone>) onZonesUpdated,
    Function(String)? onError,
  }) {
    // Evitar múltiples timers
    stopAutoRefresh();
    
    debugPrint('🔄 Iniciando auto-refresh de zonas de demanda');
    _isRefreshing = true;
    _isFetchInProgress = false;
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    _lastLocationUpdateAt = DateTime.now();
    _locationDirty = true;
    _consecutiveEmptyResponses = 0;
    _serverSuggestedRefreshSeconds = refreshIntervalSeconds;
    
    // Primera carga inmediata
    unawaited(_fetchAndNotify(onZonesUpdated, onError));
    _scheduleNextRefresh(onZonesUpdated, onError);
  }
  
  /// Actualizar ubicación del conductor para el auto-refresh
  static void updateLocation({
    required double latitude,
    required double longitude,
    required Function(List<DemandZone>) onZonesUpdated,
    Function(String)? onError,
  }) {
    final previousLatitude = _currentLatitude;
    final previousLongitude = _currentLongitude;

    _currentLatitude = latitude;
    _currentLongitude = longitude;
    _lastLocationUpdateAt = DateTime.now();

    if (!_isRefreshing) {
      return;
    }

    final hasPreviousUpdate = previousLatitude != null && previousLongitude != null;
    final movedEnough = hasPreviousUpdate && _cachedZones.isNotEmpty
      ? _hasSignificantLocationChange(
        latitude,
        longitude,
        previousLatitude,
        previousLongitude,
        )
        : true;

    if (movedEnough) {
      _locationDirty = true;
      final secondsSinceLastFetch = _lastFetchAt == null
          ? 999
          : DateTime.now().difference(_lastFetchAt!).inSeconds;

      if (!_isFetchInProgress && secondsSinceLastFetch >= minRefreshIntervalSeconds) {
        unawaited(_fetchAndNotify(onZonesUpdated, onError));
      }
    }
  }
  
  /// Detener actualización automática
  static void stopAutoRefresh() {
    _isRefreshing = false;
    _isFetchInProgress = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _locationDirty = false;
    _consecutiveEmptyResponses = 0;
    _serverSuggestedRefreshSeconds = refreshIntervalSeconds;
    _currentLatitude = null;
    _currentLongitude = null;
    debugPrint('⏹️ Auto-refresh de zonas de demanda detenido');
  }
  
  /// Obtener zonas en caché
  static List<DemandZone> get cachedZones => _cachedZones;
  
  /// Verificar si hay datos en caché recientes (menos de 1 minuto)
  static bool get hasFreshCache {
    if (_lastUpdate == null || _cachedZones.isEmpty) return false;
    return DateTime.now().difference(_lastUpdate!).inMinutes < 1;
  }
  
  /// Limpiar caché
  static void clearCache() {
    _cachedZones = [];
    _lastUpdate = null;
    _lastFetchAt = null;
    _consecutiveEmptyResponses = 0;
    _locationDirty = false;
    _serverSuggestedRefreshSeconds = refreshIntervalSeconds;
  }
  
  /// Método interno para obtener y notificar cambios
  static Future<void> _fetchAndNotify(
    Function(List<DemandZone>) onZonesUpdated,
    Function(String)? onError,
  ) async {
    if (!_isRefreshing || _isFetchInProgress) return;

    final latitude = _currentLatitude;
    final longitude = _currentLongitude;
    if (latitude == null || longitude == null) {
      return;
    }

    _isFetchInProgress = true;
    _lastFetchAt = DateTime.now();

    final dynamicRadius = _consecutiveEmptyResponses >= 4 ? 15.0 : 10.0;

    final response = await getDemandZones(
      latitude: latitude,
      longitude: longitude,
      radiusKm: dynamicRadius,
      includeDemo: false,
    );

    if (response.success) {
      _serverSuggestedRefreshSeconds = response.refreshIntervalSeconds.clamp(
        minRefreshIntervalSeconds,
        60,
      );
      _locationDirty = false;
      if (response.zones.isEmpty) {
        _consecutiveEmptyResponses++;
      } else {
        _consecutiveEmptyResponses = 0;
      }
      onZonesUpdated(response.zones);
    } else if (onError != null) {
      onError(response.message ?? 'Error desconocido');
    }

    _isFetchInProgress = false;
    if (_isRefreshing) {
      _scheduleNextRefresh(onZonesUpdated, onError);
    }
  }

  static void _scheduleNextRefresh(
    Function(List<DemandZone>) onZonesUpdated,
    Function(String)? onError,
  ) {
    if (!_isRefreshing) return;

    _refreshTimer?.cancel();

    final now = DateTime.now();
    final secondsSinceLocation = _lastLocationUpdateAt == null
        ? refreshIntervalSeconds
        : now.difference(_lastLocationUpdateAt!).inSeconds;

    final shouldForceStaleRefresh = _lastFetchAt == null
        ? true
        : now.difference(_lastFetchAt!).inSeconds >= staleRefreshIntervalSeconds;

    int nextSeconds;
    final baseRefresh = _serverSuggestedRefreshSeconds;
    if (_locationDirty) {
      nextSeconds = minRefreshIntervalSeconds;
    } else if (shouldForceStaleRefresh) {
      nextSeconds = minRefreshIntervalSeconds;
    } else if (secondsSinceLocation >= 180) {
      nextSeconds = 45;
    } else {
      nextSeconds = baseRefresh;
    }

    _refreshTimer = Timer(Duration(seconds: nextSeconds), () {
      if (_isRefreshing) {
        unawaited(_fetchAndNotify(onZonesUpdated, onError));
      }
    });
  }

  static bool _hasSignificantLocationChange(
    double latitude,
    double longitude,
    double previousLatitude,
    double previousLongitude,
  ) {
    final movedKm = _calculateDistance(
      latitude,
      longitude,
      previousLatitude,
      previousLongitude,
    );

    return movedKm >= locationChangeThresholdKm;
  }
  
  /// Obtener el multiplicador de precio para una ubicación específica
  static double getSurgeMultiplierAt(double latitude, double longitude) {
    if (_cachedZones.isEmpty) return 1.0;
    
    // Buscar la zona que contiene esta ubicación
    for (final zone in _cachedZones) {
      final distance = _calculateDistance(
        latitude, longitude,
        zone.centerLat, zone.centerLng,
      );
      
      if (distance <= zone.radiusKm) {
        return zone.surgeMultiplier;
      }
    }
    
    return 1.0; // Sin surge
  }
  
  /// Obtener la zona de demanda en una ubicación
  static DemandZone? getDemandZoneAt(double latitude, double longitude) {
    if (_cachedZones.isEmpty) return null;
    
    for (final zone in _cachedZones) {
      final distance = _calculateDistance(
        latitude, longitude,
        zone.centerLat, zone.centerLng,
      );
      
      if (distance <= zone.radiusKm) {
        return zone;
      }
    }
    
    return null;
  }
  
  /// Calcular distancia entre dos puntos (fórmula simplificada)
  static double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    // Aproximación simple para distancias cortas
    const double kmPerDegreeLat = 111.0;
    final double kmPerDegreeLon = 111.0 * math.cos(lat1 * math.pi / 180).abs();
    
    final double dLat = (lat2 - lat1) * kmPerDegreeLat;
    final double dLon = (lon2 - lon1) * kmPerDegreeLon;
    
    return math.sqrt(dLat * dLat + dLon * dLon);
  }
}

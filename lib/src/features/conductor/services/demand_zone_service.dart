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
  static List<DemandZone> _cachedZones = [];
  static DateTime? _lastUpdate;
  
  /// Intervalo de actualización en segundos
  static const int refreshIntervalSeconds = 30;
  
  /// URL base del API
  static String get _baseUrl => AppConfig.baseUrl;
  
  /// Obtener zonas de demanda cercanas a una ubicación
  static Future<DemandZonesResponse> getDemandZones({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    double zoneSizeKm = 0.5,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/conductor/get_demand_zones.php');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitud': latitude,
          'longitud': longitude,
          'radio_km': radiusKm,
          'zone_size_km': zoneSizeKm,
        }),
      ).timeout(const Duration(seconds: 10));
      
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
    
    // Primera carga inmediata
    _fetchAndNotify(latitude, longitude, onZonesUpdated, onError);
    
    // Configurar timer para actualizaciones periódicas
    _refreshTimer = Timer.periodic(
      const Duration(seconds: refreshIntervalSeconds),
      (timer) {
        if (_isRefreshing) {
          _fetchAndNotify(latitude, longitude, onZonesUpdated, onError);
        }
      },
    );
  }
  
  /// Actualizar ubicación del conductor para el auto-refresh
  static void updateLocation({
    required double latitude,
    required double longitude,
    required Function(List<DemandZone>) onZonesUpdated,
    Function(String)? onError,
  }) {
    if (_isRefreshing) {
      // Solo actualizar en la próxima iteración si está activo
      _fetchAndNotify(latitude, longitude, onZonesUpdated, onError);
    }
  }
  
  /// Detener actualización automática
  static void stopAutoRefresh() {
    _isRefreshing = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
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
  }
  
  /// Método interno para obtener y notificar cambios
  static Future<void> _fetchAndNotify(
    double latitude,
    double longitude,
    Function(List<DemandZone>) onZonesUpdated,
    Function(String)? onError,
  ) async {
    final response = await getDemandZones(
      latitude: latitude,
      longitude: longitude,
    );
    
    if (response.success) {
      onZonesUpdated(response.zones);
    } else if (onError != null) {
      onError(response.message ?? 'Error desconocido');
    }
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de datos para recuperar un viaje
class TripRecoveryData {
  final int tripId;           // ID de la solicitud
  final String userRole;      // 'conductor' o 'cliente'
  final DateTime startTime;   // Hora de inicio REAL
  final double accumulatedDistance; // Distancia acumulada (principalmente para conductor)
  final double currentPrice;  // Precio parcial (si aplica)
  
  TripRecoveryData({
    required this.tripId,
    required this.userRole,
    required this.startTime,
    required this.accumulatedDistance,
    this.currentPrice = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'userRole': userRole,
    'startTime': startTime.toIso8601String(),
    'accumulatedDistance': accumulatedDistance,
    'currentPrice': currentPrice,
  };

  factory TripRecoveryData.fromJson(Map<String, dynamic> json) {
    return TripRecoveryData(
      tripId: json['tripId'],
      userRole: json['userRole'],
      startTime: DateTime.parse(json['startTime']),
      accumulatedDistance: (json['accumulatedDistance'] as num).toDouble(),
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Servicio encargado de la persistencia local del viaje activo.
/// 
/// Actúa como "Caja Negra" que sobrevive a reinicios de la app.
class TripPersistenceService {
  static const String _keyActiveTrip = 'viax_active_trip_data';

  // Singleton
  static final TripPersistenceService _instance = TripPersistenceService._internal();
  factory TripPersistenceService() => _instance;
  TripPersistenceService._internal();

  /// Guarda el estado inicial del viaje
  Future<void> saveActiveTrip({
    required int tripId,
    required String role,
    required DateTime startTime,
    double initialDistance = 0.0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = TripRecoveryData(
        tripId: tripId,
        userRole: role,
        startTime: startTime,
        accumulatedDistance: initialDistance,
      );
      
      await prefs.setString(_keyActiveTrip, jsonEncode(data.toJson()));
      debugPrint('💾 [Persistence] Viaje guardado: ID $tripId, Rol $role');
    } catch (e) {
      debugPrint('⚠️ [Persistence] Error guardando viaje: $e');
    }
  }

  /// Actualiza la distancia acumulada (y precio si aplica)
  Future<void> updateTripProgress({
    required double distanceKm,
    double? currentPrice,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyActiveTrip);
      
      if (jsonStr == null) return; // No hay viaje activo

      final currentData = TripRecoveryData.fromJson(jsonDecode(jsonStr));
      
      final newData = TripRecoveryData(
        tripId: currentData.tripId,
        userRole: currentData.userRole,
        startTime: currentData.startTime,
        accumulatedDistance: distanceKm,
        currentPrice: currentPrice ?? currentData.currentPrice,
      );

      await prefs.setString(_keyActiveTrip, jsonEncode(newData.toJson()));
      // No loguear cada update para no saturar consola
    } catch (e) {
      debugPrint('⚠️ [Persistence] Error actualizando progreso: $e');
    }
  }

  /// Recupera el viaje activo si existe
  Future<TripRecoveryData?> getActiveTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyActiveTrip);
      
      if (jsonStr == null) return null;

      debugPrint('♻️ [Persistence] Viaje recuperado de almacenamiento local');
      return TripRecoveryData.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('⚠️ [Persistence] Error recuperando viaje: $e');
      return null;
    }
  }

  /// Limpia el viaje activo (al finalizar o cancelar)
  Future<void> clearActiveTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveTrip);
      debugPrint('🗑️ [Persistence] Viaje activo eliminado');
    } catch (e) {
      debugPrint('⚠️ [Persistence] Error limpiando viaje: $e');
    }
  }
}

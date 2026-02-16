// lib/src/global/services/traffic_service.dart
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/core/network/network_request_executor.dart';
import 'app_secrets_service.dart';
import 'quota_monitor_service.dart';

/// Servicio de informaciÃ³n de trÃ¡fico usando TomTom API
/// Plan gratuito: 2,500 solicitudes por dÃ­a
/// DocumentaciÃ³n: https://developer.tomtom.com/traffic-api/documentation
class TrafficService {
  static const String _baseUrl = 'https://api.tomtom.com';
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  // ============================================
  // TRAFFIC FLOW API
  // ============================================
  
  /// Obtener datos de flujo de trÃ¡fico en una ubicaciÃ³n
  /// 
  /// Retorna informaciÃ³n sobre:
  /// - Velocidad actual vs velocidad libre de flujo
  /// - Nivel de congestiÃ³n
  /// - Confiabilidad de los datos
  static Future<TrafficFlow?> getTrafficFlow({
    required LatLng location,
    int zoom = 15, // 0-22, mayor = mÃ¡s detalle
  }) async {
    try {
      if (AppSecretsService.instance.tomtomApiKey.isEmpty) {
        print('TomTom API Key no configurada');
        return null;
      }

      final url = Uri.parse(
        '$_baseUrl/traffic/services/4/flowSegmentData/absolute/$zoom/json'
        '?point=${location.latitude},${location.longitude}'
        '&key=${AppSecretsService.instance.tomtomApiKey}'
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        // Incrementar contador de uso
        await QuotaMonitorService.incrementTomTomTraffic();

        final data = result.json!;
        return TrafficFlow.fromJson(data);
      } else {
        print('Error en TomTom Traffic Flow: ${result.error?.userMessage}');
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo trÃ¡fico: $e');
      return null;
    }
  }

  // ============================================
  // TRAFFIC INCIDENTS API
  // ============================================
  
  /// Obtener incidentes de trÃ¡fico en un Ã¡rea (accidentes, obras, etc.)
  /// 
  /// [boundingBox] - Ãrea de bÃºsqueda: [minLat, minLng, maxLat, maxLng]
  static Future<List<TrafficIncident>> getTrafficIncidents({
    required LatLng location,
    double radiusKm = 5.0,
  }) async {
    try {
      if (AppSecretsService.instance.tomtomApiKey.isEmpty) {
        print('TomTom API Key no configurada');
        return [];
      }

      // Calcular bounding box aproximado
      // 1 grado lat â‰ˆ 111km, ajustar por radio
      final latDelta = radiusKm / 111.0;
      final lngDelta = radiusKm / (111.0 * cos(location.latitude * pi / 180));
      
      final minLat = location.latitude - latDelta;
      final maxLat = location.latitude + latDelta;
      final minLng = location.longitude - lngDelta;
      final maxLng = location.longitude + lngDelta;

      final url = Uri.parse(
        '$_baseUrl/traffic/services/5/incidentDetails'
        '?bbox=$minLng,$minLat,$maxLng,$maxLat'
        '&key=${AppSecretsService.instance.tomtomApiKey}'
        '&language=es-ES'
      );

      final result = await _network.getJson(
        url: url,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.json != null) {
        await QuotaMonitorService.incrementTomTomTraffic();

        final data = result.json!;
        
        if (data['incidents'] != null) {
          return (data['incidents'] as List)
              .map((incident) => TrafficIncident.fromJson(incident))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo incidentes: $e');
      return [];
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Obtener color segÃºn nivel de trÃ¡fico (para visualizaciÃ³n)
  static String getTrafficColor(double freeFlowSpeed, double currentSpeed) {
    if (currentSpeed >= freeFlowSpeed * 0.8) {
      return '#00FF00'; // Verde - fluido
    } else if (currentSpeed >= freeFlowSpeed * 0.5) {
      return '#FFFF00'; // Amarillo - moderado
    } else if (currentSpeed >= freeFlowSpeed * 0.3) {
      return '#FFA500'; // Naranja - lento
    } else {
      return '#FF0000'; // Rojo - congestionado
    }
  }
}

// ============================================
// MODELOS DE DATOS
// ============================================

/// InformaciÃ³n de flujo de trÃ¡fico
class TrafficFlow {
  final double currentSpeed; // km/h
  final double freeFlowSpeed; // km/h velocidad sin trÃ¡fico
  final double confidence; // 0.0 - 1.0
  final String roadName;

  TrafficFlow({
    required this.currentSpeed,
    required this.freeFlowSpeed,
    required this.confidence,
    required this.roadName,
  });

  factory TrafficFlow.fromJson(Map<String, dynamic> json) {
    final flowData = json['flowSegmentData'];
    
    return TrafficFlow(
      currentSpeed: (flowData?['currentSpeed'] as num?)?.toDouble() ?? 0.0,
      freeFlowSpeed: (flowData?['freeFlowSpeed'] as num?)?.toDouble() ?? 0.0,
      confidence: (flowData?['confidence'] as num?)?.toDouble() ?? 0.0,
      roadName: flowData?['roadName'] ?? 'Desconocido',
    );
  }

  /// Porcentaje de velocidad actual vs velocidad libre (0.0 - 1.0)
  double get speedRatio => 
      freeFlowSpeed > 0 ? currentSpeed / freeFlowSpeed : 1.0;

  /// Nivel de congestiÃ³n
  TrafficLevel get trafficLevel {
    if (speedRatio >= 0.8) return TrafficLevel.free;
    if (speedRatio >= 0.5) return TrafficLevel.moderate;
    if (speedRatio >= 0.3) return TrafficLevel.slow;
    return TrafficLevel.congested;
  }

  /// DescripciÃ³n del trÃ¡fico
  String get description {
    switch (trafficLevel) {
      case TrafficLevel.free:
        return 'TrÃ¡fico fluido';
      case TrafficLevel.moderate:
        return 'TrÃ¡fico moderado';
      case TrafficLevel.slow:
        return 'TrÃ¡fico lento';
      case TrafficLevel.congested:
        return 'TrÃ¡fico congestionado';
    }
  }

  /// Color para visualizaciÃ³n
  String get color {
    switch (trafficLevel) {
      case TrafficLevel.free:
        return '#00FF00';
      case TrafficLevel.moderate:
        return '#FFFF00';
      case TrafficLevel.slow:
        return '#FFA500';
      case TrafficLevel.congested:
        return '#FF0000';
    }
  }
}

/// Incidente de trÃ¡fico
class TrafficIncident {
  final String id;
  final String type; // accident, congestion, roadWork, etc.
  final String description;
  final LatLng location;
  final int severity; // 0 (bajo) - 4 (alto)
  final DateTime? from;
  final DateTime? to;

  TrafficIncident({
    required this.id,
    required this.type,
    required this.description,
    required this.location,
    required this.severity,
    this.from,
    this.to,
  });

  factory TrafficIncident.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'];
    final geometry = json['geometry'];
    
    // Extraer coordenadas
    double lat = 0.0;
    double lng = 0.0;
    
    if (geometry?['coordinates'] != null) {
      final coords = geometry['coordinates'];
      if (coords is List && coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }

    return TrafficIncident(
      id: json['id'] ?? '',
      type: properties?['iconCategory'] ?? 'unknown',
      description: properties?['description'] ?? 'Sin descripciÃ³n',
      location: LatLng(lat, lng),
      severity: properties?['magnitudeOfDelay'] ?? 0,
      from: properties?['from'] != null 
          ? DateTime.tryParse(properties['from']) 
          : null,
      to: properties?['to'] != null 
          ? DateTime.tryParse(properties['to']) 
          : null,
    );
  }

  /// Icono segÃºn tipo de incidente
  String get icon {
    switch (type.toLowerCase()) {
      case 'accident':
        return 'ðŸš¨';
      case 'roadwork':
        return 'ðŸš§';
      case 'congestion':
        return 'ðŸš—';
      case 'roadclosure':
        return 'â›”';
      default:
        return 'âš ï¸';
    }
  }

  /// Nivel de severidad como texto
  String get severityText {
    switch (severity) {
      case 0:
        return 'Bajo';
      case 1:
        return 'Menor';
      case 2:
        return 'Moderado';
      case 3:
        return 'Mayor';
      case 4:
        return 'CrÃ­tico';
      default:
        return 'Desconocido';
    }
  }
}

/// Niveles de trÃ¡fico
enum TrafficLevel {
  free,        // Verde - fluido (>80%)
  moderate,    // Amarillo - moderado (50-80%)
  slow,        // Naranja - lento (30-50%)
  congested,   // Rojo - congestionado (<30%)
}

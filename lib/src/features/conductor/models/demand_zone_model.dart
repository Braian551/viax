/// Modelo para representar zonas de alta demanda en el mapa
/// Similar al sistema de "surge pricing" de Uber/Didi
///
/// Muestra zonas con colores según el nivel de demanda y
/// multiplicadores de precio aplicables.

class DemandZone {
  final String id;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final int demandLevel; // 1-5 (1=bajo, 5=muy alto)
  final double surgeMultiplier; // 1.0x - 3.0x
  final int activeRequests; // Número de solicitudes activas en la zona
  final int availableDrivers; // Conductores disponibles en la zona
  final DateTime lastUpdated;

  const DemandZone({
    required this.id,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.demandLevel,
    required this.surgeMultiplier,
    required this.activeRequests,
    required this.availableDrivers,
    required this.lastUpdated,
  });

  /// Helper para convertir a double de forma segura
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Helper para convertir a int de forma segura
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Crear desde JSON del backend
  factory DemandZone.fromJson(Map<String, dynamic> json) {
    return DemandZone(
      id: json['id']?.toString() ?? '',
      centerLat: _toDouble(json['center_lat'] ?? json['latitud']),
      centerLng: _toDouble(json['center_lng'] ?? json['longitud']),
      radiusKm: _toDouble(json['radius_km'] ?? 0.5),
      demandLevel: _toInt(json['demand_level'] ?? json['nivel_demanda'] ?? 1),
      surgeMultiplier: _toDouble(
        json['surge_multiplier'] ?? json['multiplicador'] ?? 1.0,
      ),
      activeRequests: _toInt(
        json['active_requests'] ?? json['solicitudes_activas'] ?? 0,
      ),
      availableDrivers: _toInt(
        json['available_drivers'] ?? json['conductores_disponibles'] ?? 0,
      ),
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'radius_km': radiusKm,
      'demand_level': demandLevel,
      'surge_multiplier': surgeMultiplier,
      'active_requests': activeRequests,
      'available_drivers': availableDrivers,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  /// Obtener color según nivel de demanda (tonalidades azules - diseño Viax)
  /// Escala de colores azules: más oscuro = más demanda
  int get demandColorValue {
    switch (demandLevel) {
      case 1:
        return 0x4D4DD0E1; // Cyan claro suave (baja demanda)
      case 2:
        return 0x6629B6F6; // Azul cielo suave
      case 3:
        return 0x801E88E5; // Azul medio
      case 4:
        return 0x991565C0; // Azul oscuro
      case 5:
        return 0xB31A237E; // Azul índigo (alta demanda)
      default:
        return 0x3326C6DA;
    }
  }

  /// Obtener color del borde (tonalidades azules)
  int get borderColorValue {
    switch (demandLevel) {
      case 1:
        return 0xFF26C6DA; // Cyan
      case 2:
        return 0xFF29B6F6; // Azul cielo
      case 3:
        return 0xFF1E88E5; // Azul
      case 4:
        return 0xFF1565C0; // Azul oscuro
      case 5:
        return 0xFF1A237E; // Azul índigo
      default:
        return 0xFF26C6DA;
    }
  }

  /// Obtener etiqueta del nivel de demanda
  String get demandLabel {
    switch (demandLevel) {
      case 1:
        return 'Baja';
      case 2:
        return 'Normal';
      case 3:
        return 'Media';
      case 4:
        return 'Alta';
      case 5:
        return 'Muy alta';
      default:
        return 'Normal';
    }
  }

  /// Obtener texto del multiplicador formateado
  String get surgeText {
    if (surgeMultiplier <= 1.0) return '';
    return '${surgeMultiplier.toStringAsFixed(1)}x';
  }

  /// Verificar si tiene recargo activo
  bool get hasSurge => surgeMultiplier > 1.0;

  /// Ratio demanda/oferta (solicitudes por conductor)
  double get demandRatio {
    if (availableDrivers == 0) return activeRequests.toDouble();
    return activeRequests / availableDrivers;
  }

  @override
  String toString() {
    return 'DemandZone(id: $id, level: $demandLevel, surge: ${surgeMultiplier}x, requests: $activeRequests)';
  }
}

/// Respuesta del API de zonas de demanda
class DemandZonesResponse {
  final bool success;
  final String? message;
  final List<DemandZone> zones;
  final DateTime? serverTime;
  final int refreshIntervalSeconds;

  const DemandZonesResponse({
    required this.success,
    this.message,
    required this.zones,
    this.serverTime,
    this.refreshIntervalSeconds = 30,
  });

  factory DemandZonesResponse.fromJson(Map<String, dynamic> json) {
    final zonesData = json['zones'] ?? json['zonas'] ?? [];
    return DemandZonesResponse(
      success: json['success'] == true,
      message: json['message']?.toString(),
      zones: (zonesData as List)
          .map((z) => DemandZone.fromJson(z as Map<String, dynamic>))
          .toList(),
      serverTime: json['server_time'] != null
          ? DateTime.tryParse(json['server_time'].toString())
          : null,
      refreshIntervalSeconds: json['refresh_interval'] ?? 30,
    );
  }

  factory DemandZonesResponse.error(String message) {
    return DemandZonesResponse(success: false, message: message, zones: []);
  }
}

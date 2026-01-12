/// Modelos para el sistema de empresas y vehículos por municipio
/// Estos modelos representan la respuesta del endpoint get_companies_by_municipality

/// Información de una empresa con sus conductores y tarifa para un tipo de vehículo
class CompanyVehicleOption {
  final int id;
  final String nombre;
  final String? logoUrl;
  final int conductores;
  final double?
  distanciaConductorKm; // Nullable: null si no hay conductores cerca
  final double tarifaTotal;
  final String periodo;
  final double recargoPorcentaje;

  CompanyVehicleOption({
    required this.id,
    required this.nombre,
    this.logoUrl,
    required this.conductores,
    this.distanciaConductorKm,
    required this.tarifaTotal,
    required this.periodo,
    required this.recargoPorcentaje,
  });

  /// Indica si hay conductores disponibles para esta empresa/vehículo
  bool get hasConductores => conductores > 0;

  factory CompanyVehicleOption.fromJson(Map<String, dynamic> json) {
    return CompanyVehicleOption(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      logoUrl: json['logo_url'],
      conductores: json['conductores'] ?? 0,
      distanciaConductorKm: json['distancia_conductor_km']?.toDouble(),
      tarifaTotal: (json['tarifa_total'] ?? 0).toDouble(),
      periodo: json['periodo'] ?? 'normal',
      recargoPorcentaje: (json['recargo_porcentaje'] ?? 0).toDouble(),
    );
  }
}

/// Tipo de vehículo disponible con las empresas que lo ofrecen
class AvailableVehicleType {
  final String tipo;
  final String nombre;
  final List<CompanyVehicleOption> empresas;

  AvailableVehicleType({
    required this.tipo,
    required this.nombre,
    required this.empresas,
  });

  /// Empresa recomendada (la primera, que es la más cercana)
  CompanyVehicleOption? get empresaRecomendada =>
      empresas.isNotEmpty ? empresas.first : null;

  /// Tarifa de la empresa recomendada
  double? get tarifaRecomendada => empresaRecomendada?.tarifaTotal;

  factory AvailableVehicleType.fromJson(Map<String, dynamic> json) {
    return AvailableVehicleType(
      tipo: json['tipo'] ?? '',
      nombre: json['nombre'] ?? '',
      empresas:
          (json['empresas'] as List<dynamic>?)
              ?.map((e) => CompanyVehicleOption.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// Información completa de una empresa
class CompanyInfo {
  final int id;
  final String nombre;
  final String? logoUrl;
  final String? municipio;
  final List<String> tiposVehiculo;
  final int conductoresCercanos;
  final double? distanciaPromedioKm;

  CompanyInfo({
    required this.id,
    required this.nombre,
    this.logoUrl,
    this.municipio,
    required this.tiposVehiculo,
    required this.conductoresCercanos,
    this.distanciaPromedioKm,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) {
    return CompanyInfo(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      logoUrl: json['logo_url'],
      municipio: json['municipio'],
      tiposVehiculo: List<String>.from(json['tipos_vehiculo'] ?? []),
      conductoresCercanos: json['conductores_cercanos'] ?? 0,
      distanciaPromedioKm: json['distancia_promedio_km']?.toDouble(),
    );
  }
}

/// Respuesta completa del endpoint
class CompanyVehicleResponse {
  final bool success;
  final String? municipio;
  final int? empresaRecomendadaId;
  final int totalEmpresas;
  final int totalTiposVehiculo;
  final int totalConductoresCerca;
  final List<AvailableVehicleType> vehiculosDisponibles;
  final List<CompanyInfo> empresas;
  final String? message;

  CompanyVehicleResponse({
    required this.success,
    this.municipio,
    this.empresaRecomendadaId,
    this.totalEmpresas = 0,
    this.totalTiposVehiculo = 0,
    this.totalConductoresCerca = 0,
    this.vehiculosDisponibles = const [],
    this.empresas = const [],
    this.message,
  });

  /// Verifica si hay vehículos disponibles
  bool get hasVehicles => vehiculosDisponibles.isNotEmpty;

  /// Verifica si hay conductores cerca
  bool get hasConductores => totalConductoresCerca > 0;

  /// Verifica si hay empresas en la zona
  bool get hasEmpresas => totalEmpresas > 0;

  /// Obtiene la empresa recomendada
  CompanyInfo? get empresaRecomendada {
    if (empresaRecomendadaId == null) return null;
    try {
      return empresas.firstWhere((e) => e.id == empresaRecomendadaId);
    } catch (_) {
      return null;
    }
  }

  factory CompanyVehicleResponse.fromJson(Map<String, dynamic> json) {
    return CompanyVehicleResponse(
      success: json['success'] ?? false,
      municipio: json['municipio'],
      empresaRecomendadaId: json['empresa_recomendada_id'],
      totalEmpresas: json['total_empresas'] ?? 0,
      totalTiposVehiculo: json['total_tipos_vehiculo'] ?? 0,
      totalConductoresCerca: json['total_conductores_cerca'] ?? 0,
      vehiculosDisponibles:
          (json['vehiculos_disponibles'] as List<dynamic>?)
              ?.map((e) => AvailableVehicleType.fromJson(e))
              .toList() ??
          [],
      empresas:
          (json['empresas'] as List<dynamic>?)
              ?.map((e) => CompanyInfo.fromJson(e))
              .toList() ??
          [],
      message: json['message'],
    );
  }

  factory CompanyVehicleResponse.error(String message) {
    return CompanyVehicleResponse(success: false, message: message);
  }
}

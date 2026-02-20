/// Modelos para el sistema de empresas y vehículos por municipio
/// Estos modelos representan la respuesta del endpoint get_companies_by_municipality
library;

int _toInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _toDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Información de una empresa con sus conductores y tarifa para un tipo de vehículo
class CompanyVehicleOption {
  final int id;
  final String nombre;
  final String? logoUrl;
  final int conductores;
  final double?
  distanciaConductorKm; // Nullable: null si no hay conductores cerca
  final double tarifaTotal;
  final double tarifaBase;
  final double costoDistancia;
  final double costoTiempo;
  final double recargoPrecio;
  final String periodo;
  final double recargoPorcentaje;
  final double calificacion;

  CompanyVehicleOption({
    required this.id,
    required this.nombre,
    this.logoUrl,
    required this.conductores,
    this.distanciaConductorKm,
    required this.tarifaTotal,
    required this.tarifaBase,
    required this.costoDistancia,
    required this.costoTiempo,
    required this.recargoPrecio,
    required this.periodo,
    required this.recargoPorcentaje,
    this.calificacion = 0.0,
  });

  /// Indica si hay conductores disponibles para esta empresa/vehículo
  bool get hasConductores => conductores > 0 || distanciaConductorKm != null;

  factory CompanyVehicleOption.fromJson(Map<String, dynamic> json) {
    final conductoresValue =
        json['conductores'] ??
        json['conductores_cercanos'] ??
        json['total_conductores'] ??
        json['drivers_count'] ??
        json['available_drivers'];

    return CompanyVehicleOption(
      id: _toInt(json['id']),
      nombre: json['nombre'] ?? '',
      logoUrl: json['logo_url'],
      conductores: _toInt(conductoresValue),
      distanciaConductorKm:
          json['distancia_conductor_km'] != null
              ? _toDouble(json['distancia_conductor_km'])
              : null,
      tarifaTotal: _toDouble(json['tarifa_total']),
      tarifaBase: _toDouble(json['tarifa_base']),
      costoDistancia: _toDouble(json['costo_distancia']),
      costoTiempo: _toDouble(json['costo_tiempo']),
      recargoPrecio: _toDouble(json['recargo_precio']),
      periodo: json['periodo'] ?? 'normal',
      recargoPorcentaje: _toDouble(json['recargo_porcentaje']),
      calificacion: _toDouble(json['calificacion']),
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
      id: _toInt(json['id']),
      nombre: json['nombre'] ?? '',
      logoUrl: json['logo_url'],
      municipio: json['municipio'],
      tiposVehiculo: List<String>.from(json['tipos_vehiculo'] ?? []),
      conductoresCercanos:
          _toInt(json['conductores_cercanos'] ?? json['total_conductores']),
      distanciaPromedioKm:
          json['distancia_promedio_km'] != null
              ? _toDouble(json['distancia_promedio_km'])
              : null,
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
      empresaRecomendadaId:
        json['empresa_recomendada_id'] != null
          ? _toInt(json['empresa_recomendada_id'])
          : null,
      totalEmpresas: _toInt(json['total_empresas']),
      totalTiposVehiculo: _toInt(json['total_tipos_vehiculo']),
      totalConductoresCerca:
        _toInt(json['total_conductores_cerca'] ?? json['total_conductores']),
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

/// Información detallada de una empresa (para el Sheet de detalles)
class CompanyDetails {
  final int id;
  final String nombre;
  final String? logoUrl;
  final bool verificada;
  final String? descripcion;
  final String? telefono;
  final String? email;
  final String? website;
  final String? municipio;
  final String? departamento;
  final int? anioFundacion;
  final int? anioRegistro;
  final int totalConductores;
  final int viajesCompletados;
  final double? calificacionPromedio;
  final int totalCalificaciones;
  final List<VehicleTypeInfo> tiposVehiculo;

  CompanyDetails({
    required this.id,
    required this.nombre,
    this.logoUrl,
    this.verificada = false,
    this.descripcion,
    this.telefono,
    this.email,
    this.website,
    this.municipio,
    this.departamento,
    this.anioFundacion,
    this.anioRegistro,
    this.totalConductores = 0,
    this.viajesCompletados = 0,
    this.calificacionPromedio,
    this.totalCalificaciones = 0,
    this.tiposVehiculo = const [],
  });

  factory CompanyDetails.fromJson(Map<String, dynamic> json) {
    return CompanyDetails(
      id: _toInt(json['id']),
      nombre: json['nombre'] ?? '',
      logoUrl: json['logo_url'],
      verificada: json['verificada'] ?? false,
      descripcion: json['descripcion'],
      telefono: json['telefono'],
      email: json['email'],
      website: json['website'],
      municipio: json['municipio'],
      departamento: json['departamento'],
        anioFundacion:
          json['anio_fundacion'] != null
            ? _toInt(json['anio_fundacion'])
            : null,
        anioRegistro:
          json['anio_registro'] != null
            ? _toInt(json['anio_registro'])
            : null,
        totalConductores: _toInt(json['total_conductores']),
        viajesCompletados: _toInt(json['viajes_completados']),
        calificacionPromedio:
          json['calificacion_promedio'] != null
            ? _toDouble(json['calificacion_promedio'])
            : null,
        totalCalificaciones: _toInt(json['total_calificaciones']),
      tiposVehiculo: (json['tipos_vehiculo'] as List<dynamic>?)
              ?.map((e) => VehicleTypeInfo.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// Info básica de un tipo de vehículo
class VehicleTypeInfo {
  final String codigo;
  final String nombre;

  VehicleTypeInfo({required this.codigo, required this.nombre});

  factory VehicleTypeInfo.fromJson(Map<String, dynamic> json) {
    return VehicleTypeInfo(
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
    );
  }
}


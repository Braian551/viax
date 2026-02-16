/// Company Pricing Entity
/// Domain entity representing a pricing configuration
library;

class CompanyPricing {
  final int? id;
  final dynamic empresaId;
  final String tipoVehiculo;
  final double tarifaBase;
  final double costoPorKm;
  final double costoPorMinuto;
  final double tarifaMinima;
  final double recargoHoraPico;
  final double recargoNocturno;
  final double recargoFestivo;
  final double comisionPlataforma;
  final bool esGlobal;
  final bool activo;

  CompanyPricing({
    this.id,
    this.empresaId,
    required this.tipoVehiculo,
    required this.tarifaBase,
    required this.costoPorKm,
    required this.costoPorMinuto,
    required this.tarifaMinima,
    this.recargoHoraPico = 0,
    this.recargoNocturno = 0,
    this.recargoFestivo = 0,
    this.comisionPlataforma = 0,
    this.esGlobal = true,
    this.activo = true,
  });

  factory CompanyPricing.fromJson(Map<String, dynamic> json) {
    return CompanyPricing(
      id: json['id'],
      empresaId: json['empresa_id'],
      tipoVehiculo: json['tipo_vehiculo'] ?? '',
      tarifaBase: _toDouble(json['tarifa_base']),
      costoPorKm: _toDouble(json['costo_por_km']),
      costoPorMinuto: _toDouble(json['costo_por_minuto']),
      tarifaMinima: _toDouble(json['tarifa_minima']),
      recargoHoraPico: _toDouble(json['recargo_hora_pico']),
      recargoNocturno: _toDouble(json['recargo_nocturno']),
      recargoFestivo: _toDouble(json['recargo_festivo']),
      comisionPlataforma: _toDouble(json['comision_plataforma']),
      esGlobal: json['es_global'] == true,
      activo: json['activo'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (empresaId != null) 'empresa_id': empresaId,
      'tipo_vehiculo': tipoVehiculo,
      'tarifa_base': tarifaBase,
      'costo_por_km': costoPorKm,
      'costo_por_minuto': costoPorMinuto,
      'tarifa_minima': tarifaMinima,
      'recargo_hora_pico': recargoHoraPico,
      'recargo_nocturno': recargoNocturno,
      'recargo_festivo': recargoFestivo,
      'comision_plataforma': comisionPlataforma,
      'activo': activo ? 1 : 0,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Company Reports Model
/// Modelo de datos para reportes de empresa

class CompanyReportsData {
  final String periodo;
  final TripStats tripStats;
  final EarningsStats earningsStats;
  final DriverStats driverStats;
  final TrendData trends;
  final ChartData chartData;
  final List<TopDriver> topDrivers;
  final List<VehicleDistribution> vehicleDistribution;
  final List<int> peakHours;

  CompanyReportsData({
    required this.periodo,
    required this.tripStats,
    required this.earningsStats,
    required this.driverStats,
    required this.trends,
    required this.chartData,
    required this.topDrivers,
    required this.vehicleDistribution,
    required this.peakHours,
  });

  factory CompanyReportsData.fromJson(Map<String, dynamic> json) {
    return CompanyReportsData(
      periodo: json['periodo'] ?? '7d',
      tripStats: TripStats.fromJson(json['trip_stats'] ?? {}),
      earningsStats: EarningsStats.fromJson(json['earnings_stats'] ?? {}),
      driverStats: DriverStats.fromJson(json['driver_stats'] ?? {}),
      trends: TrendData.fromJson(json['trends'] ?? {}),
      chartData: ChartData.fromJson(json['chart_data'] ?? {}),
      topDrivers:
          (json['top_drivers'] as List<dynamic>?)
              ?.map((e) => TopDriver.fromJson(e))
              .toList() ??
          [],
      vehicleDistribution:
          (json['vehicle_distribution'] as List<dynamic>?)
              ?.map((e) => VehicleDistribution.fromJson(e))
              .toList() ??
          [],
      peakHours:
          (json['peak_hours'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          List.filled(24, 0),
    );
  }
}

class TripStats {
  final int total;
  final int completados;
  final int cancelados;
  final int enProgreso;
  final double tasaCompletados;
  final double distanciaPromedio;
  final double distanciaTotal;
  final int duracionPromedio;

  TripStats({
    required this.total,
    required this.completados,
    required this.cancelados,
    required this.enProgreso,
    required this.tasaCompletados,
    required this.distanciaPromedio,
    required this.distanciaTotal,
    required this.duracionPromedio,
  });

  factory TripStats.fromJson(Map<String, dynamic> json) {
    return TripStats(
      total: json['total'] ?? 0,
      completados: json['completados'] ?? 0,
      cancelados: json['cancelados'] ?? 0,
      enProgreso: json['en_progreso'] ?? 0,
      tasaCompletados: (json['tasa_completados'] ?? 0).toDouble(),
      distanciaPromedio: (json['distancia_promedio'] ?? 0).toDouble(),
      distanciaTotal: (json['distancia_total'] ?? 0).toDouble(),
      duracionPromedio: json['duracion_promedio'] ?? 0,
    );
  }
}

class EarningsStats {
  final double ingresosTotales;
  final double ingresoPromedio;
  final double ingresoMaximo;
  final double ingresoMinimo;
  final double comisionEmpresa;
  final double gananciaNeta;

  EarningsStats({
    required this.ingresosTotales,
    required this.ingresoPromedio,
    required this.ingresoMaximo,
    required this.ingresoMinimo,
    required this.comisionEmpresa,
    required this.gananciaNeta,
  });

  factory EarningsStats.fromJson(Map<String, dynamic> json) {
    return EarningsStats(
      ingresosTotales: (json['ingresos_totales'] ?? 0).toDouble(),
      ingresoPromedio: (json['ingreso_promedio'] ?? 0).toDouble(),
      ingresoMaximo: (json['ingreso_maximo'] ?? 0).toDouble(),
      ingresoMinimo: (json['ingreso_minimo'] ?? 0).toDouble(),
      comisionEmpresa: (json['comision_empresa'] ?? 0).toDouble(),
      gananciaNeta: (json['ganancia_neta'] ?? 0).toDouble(),
    );
  }
}

class DriverStats {
  final int total;
  final int activos;
  final int pendientes;
  final int inactivos;

  DriverStats({
    required this.total,
    required this.activos,
    required this.pendientes,
    required this.inactivos,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      activos: int.tryParse(json['activos']?.toString() ?? '0') ?? 0,
      pendientes: int.tryParse(json['pendientes']?.toString() ?? '0') ?? 0,
      inactivos: int.tryParse(json['inactivos']?.toString() ?? '0') ?? 0,
    );
  }
}

class TrendData {
  final TrendItem viajes;
  final TrendItem ingresos;

  TrendData({required this.viajes, required this.ingresos});

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      viajes: TrendItem.fromJson(json['viajes'] ?? {}),
      ingresos: TrendItem.fromJson(json['ingresos'] ?? {}),
    );
  }
}

class TrendItem {
  final num actual;
  final num anterior;
  final double cambioPorcentaje;
  final String tendencia;

  TrendItem({
    required this.actual,
    required this.anterior,
    required this.cambioPorcentaje,
    required this.tendencia,
  });

  bool get isPositive => tendencia == 'up';

  factory TrendItem.fromJson(Map<String, dynamic> json) {
    return TrendItem(
      actual: json['actual'] ?? 0,
      anterior: json['anterior'] ?? 0,
      cambioPorcentaje: (json['cambio_porcentaje'] ?? 0).toDouble(),
      tendencia: json['tendencia'] ?? 'up',
    );
  }
}

class ChartData {
  final List<String> labels;
  final List<int> viajes;
  final List<double> ingresos;

  ChartData({
    required this.labels,
    required this.viajes,
    required this.ingresos,
  });

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      labels:
          (json['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      viajes:
          (json['viajes'] as List<dynamic>?)?.map((e) => e as int).toList() ??
          [],
      ingresos:
          (json['ingresos'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

class TopDriver {
  final int id;
  final String nombre;
  final String? fotoPerfil;
  final int totalViajes;
  final double ingresos;
  final double rating;

  TopDriver({
    required this.id,
    required this.nombre,
    this.fotoPerfil,
    required this.totalViajes,
    required this.ingresos,
    required this.rating,
  });

  factory TopDriver.fromJson(Map<String, dynamic> json) {
    return TopDriver(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      fotoPerfil: json['foto_perfil'],
      totalViajes: json['total_viajes'] ?? 0,
      ingresos: (json['ingresos'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
    );
  }
}

class VehicleDistribution {
  final String tipo;
  final String nombre;
  final int viajes;
  final double ingresos;

  VehicleDistribution({
    required this.tipo,
    required this.nombre,
    required this.viajes,
    required this.ingresos,
  });

  factory VehicleDistribution.fromJson(Map<String, dynamic> json) {
    return VehicleDistribution(
      tipo: json['tipo'] ?? '',
      nombre: json['nombre'] ?? '',
      viajes: json['viajes'] ?? 0,
      ingresos: (json['ingresos'] ?? 0).toDouble(),
    );
  }
}

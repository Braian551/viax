import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Modelo para las ganancias
class EarningsModel {
  final double total;
  final double totalCobrado;
  final int totalViajes;
  final double promedioPorViaje;
  final double comisionPeriodo;
  final double comisionAdeudada;
  final List<EarningsDayModel> desgloseDiario;

  EarningsModel({
    required this.total,
    this.totalCobrado = 0,
    required this.totalViajes,
    required this.promedioPorViaje,
    this.comisionPeriodo = 0,
    this.comisionAdeudada = 0,
    required this.desgloseDiario,
  });

  factory EarningsModel.fromJson(Map<String, dynamic> json) {
    return EarningsModel(
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      totalCobrado: double.tryParse(json['total_cobrado']?.toString() ?? '0') ?? 0.0,
      totalViajes: int.tryParse(json['total_viajes']?.toString() ?? '0') ?? 0,
      promedioPorViaje: double.tryParse(json['promedio_por_viaje']?.toString() ?? '0') ?? 0.0,
      comisionPeriodo: double.tryParse(json['comision_periodo']?.toString() ?? '0') ?? 0.0,
      comisionAdeudada: double.tryParse(json['comision_adeudada']?.toString() ?? '0') ?? 0.0,
      desgloseDiario: (json['desglose_diario'] as List?)
          ?.map((item) => EarningsDayModel.fromJson(item))
          .toList() ?? [],
    );
  }
}

/// Modelo para las ganancias por día
class EarningsDayModel {
  final String fecha;
  final double ganancias;
  final double comision;
  final int viajes;

  EarningsDayModel({
    required this.fecha,
    required this.ganancias,
    this.comision = 0,
    required this.viajes,
  });

  factory EarningsDayModel.fromJson(Map<String, dynamic> json) {
    return EarningsDayModel(
      fecha: json['fecha']?.toString() ?? '',
      ganancias: double.tryParse(json['ganancias']?.toString() ?? '0') ?? 0.0,
      comision: double.tryParse(json['comision']?.toString() ?? '0') ?? 0.0,
      viajes: int.tryParse(json['viajes']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Servicio para gestionar las ganancias del conductor
/// 
/// NOTA: Redundante con ConductorRemoteDataSource.
/// Se mantiene por compatibilidad.
class ConductorEarningsService {
  /// URL base del microservicio de conductores
  static String get _baseUrl => AppConfig.baseUrl;

  /// Obtener ganancias del conductor
  static Future<Map<String, dynamic>> getEarnings({
    required int conductorId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      // Format dates
      final inicio = fechaInicio?.toIso8601String().split('T')[0] ?? 
                     DateTime.now().toIso8601String().split('T')[0];
      final fin = fechaFin?.toIso8601String().split('T')[0] ?? 
                  DateTime.now().toIso8601String().split('T')[0];

      final url = Uri.parse(
        '$_baseUrl/conductor/get_ganancias.php?conductor_id=$conductorId&fecha_inicio=$inicio&fecha_fin=$fin',
      );

      print('Fetching earnings: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado');
        },
      );

      print('Earnings response status: ${response.statusCode}');
      print('Earnings response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['ganancias'] != null) {
          return {
            'success': true,
            'ganancias': EarningsModel.fromJson(data['ganancias']),
            'periodo': data['periodo'],
            'message': data['message'] ?? 'Ganancias obtenidas exitosamente',
          };
        } else {
          return {
            'success': false,
            'ganancias': EarningsModel(
              total: 0,
              totalViajes: 0,
              promedioPorViaje: 0,
              desgloseDiario: [],
            ),
            'message': data['message'] ?? 'Error al obtener ganancias',
          };
        }
      } else {
        return {
          'success': false,
          'ganancias': EarningsModel(
            total: 0,
            totalViajes: 0,
            promedioPorViaje: 0,
            desgloseDiario: [],
          ),
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error en getEarnings: $e');
      return {
        'success': false,
        'ganancias': EarningsModel(
          total: 0,
          totalViajes: 0,
          promedioPorViaje: 0,
          desgloseDiario: [],
        ),
        'message': 'Error de conexiÃ³n: $e',
      };
    }
  }

  /// Obtener ganancias para hoy
  static Future<Map<String, dynamic>> getTodayEarnings({
    required int conductorId,
  }) async {
    final today = DateTime.now();
    return await getEarnings(
      conductorId: conductorId,
      fechaInicio: today,
      fechaFin: today,
    );
  }

  /// Obtener ganancias de la semana
  static Future<Map<String, dynamic>> getWeekEarnings({
    required int conductorId,
  }) async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return await getEarnings(
      conductorId: conductorId,
      fechaInicio: weekAgo,
      fechaFin: now,
    );
  }

  /// Obtener ganancias del mes
  static Future<Map<String, dynamic>> getMonthEarnings({
    required int conductorId,
  }) async {
    final now = DateTime.now();
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    return await getEarnings(
      conductorId: conductorId,
      fechaInicio: monthAgo,
      fechaFin: now,
    );
  }
}

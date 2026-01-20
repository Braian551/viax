import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Modelo para un viaje individual
class TripModel {
  final int id;
  final String tipoServicio;
  final String estado;
  final double? precioEstimado;
  final double? precioFinal;
  final double? distanciaKm;
  final double? distanciaEstimada;
  final int? duracionSegundos; // Duración real en segundos
  final int? duracionMinutos;
  final int? duracionEstimada;
  final DateTime fechaSolicitud;
  final DateTime? fechaCompletado;
  final DateTime? fechaAceptado;
  final String? origen;
  final String? destino;
  final String clienteNombre;
  final String clienteApellido;
  final int? calificacion;
  final String? comentario;
  final double? gananciaViaje;
  final double? comisionEmpresa;

  TripModel({
    required this.id,
    required this.tipoServicio,
    required this.estado,
    this.precioEstimado,
    this.precioFinal,
    this.distanciaKm,
    this.distanciaEstimada,
    this.duracionSegundos,
    this.duracionMinutos,
    this.duracionEstimada,
    required this.fechaSolicitud,
    this.fechaCompletado,
    this.fechaAceptado,
    this.origen,
    this.destino,
    required this.clienteNombre,
    required this.clienteApellido,
    this.calificacion,
    this.comentario,
    this.gananciaViaje,
    this.comisionEmpresa,
  });
  
  /// Formatea la duración de forma legible (seg/min/horas)
  String get duracionFormateada {
    final segundos = duracionSegundos ?? (duracionMinutos != null ? duracionMinutos! * 60 : null);
    if (segundos == null) return '-';
    
    if (segundos < 60) {
      return '$segundos seg';
    } else if (segundos < 3600) {
      final min = segundos ~/ 60;
      final seg = segundos % 60;
      if (seg == 0) return '$min min';
      return '$min min $seg seg';
    } else {
      final hours = segundos ~/ 3600;
      final mins = (segundos % 3600) ~/ 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    try {
      // Helper para parsear fechas de manera segura
      DateTime? parseDate(dynamic value) {
        if (value == null || value.toString().isEmpty) return null;
        try {
          return DateTime.parse(value.toString());
        } catch (e) {
          print('Error parsing date: $value - $e');
          return null;
        }
      }

      // Helper para parsear doubles de manera segura
      double? parseDouble(dynamic value) {
        if (value == null) return null;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String && value.isEmpty) return null;
        try {
          return double.parse(value.toString());
        } catch (e) {
          print('Error parsing double: $value - $e');
          return null;
        }
      }

      // Helper para parsear ints de manera segura
      int? parseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String && value.isEmpty) return null;
        try {
          return int.parse(value.toString());
        } catch (e) {
          print('Error parsing int: $value - $e');
          return null;
        }
      }

      final id = parseInt(json['id']) ?? 0;
      final fechaSolicitud = parseDate(json['fecha_solicitud']) ?? DateTime.now();
      
      return TripModel(
        id: id,
        tipoServicio: json['tipo_servicio']?.toString() ?? 'viaje',
        estado: json['estado']?.toString() ?? 'completado',
        precioEstimado: parseDouble(json['precio_estimado']),
        precioFinal: parseDouble(json['precio_final']),
        distanciaKm: parseDouble(json['distancia_km']),
        distanciaEstimada: parseDouble(json['distancia_estimada']),
        duracionSegundos: parseInt(json['duracion_segundos']),
        duracionMinutos: parseInt(json['duracion_minutos']),
        duracionEstimada: parseInt(json['duracion_estimada']),
        fechaSolicitud: fechaSolicitud,
        fechaCompletado: parseDate(json['fecha_completado']),
        fechaAceptado: parseDate(json['fecha_aceptado']),
        origen: json['origen']?.toString(),
        destino: json['destino']?.toString(),
        clienteNombre: json['cliente_nombre']?.toString() ?? '',
        clienteApellido: json['cliente_apellido']?.toString() ?? '',
        calificacion: parseInt(json['calificacion']),
        comentario: json['comentario']?.toString(),
        gananciaViaje: parseDouble(json['ganancia_viaje']),
        comisionEmpresa: parseDouble(json['comision_empresa']),
      );
    } catch (e, stackTrace) {
      print('Error in TripModel.fromJson: $e');
      print('JSON: $json');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  String get clienteNombreCompleto => '$clienteNombre $clienteApellido';
  
  double get calificacionDouble => (calificacion ?? 0).toDouble();
}

/// Modelo para paginaciÃ³n
class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: int.tryParse(json['page']?.toString() ?? '1') ?? 1,
      limit: int.tryParse(json['limit']?.toString() ?? '20') ?? 20,
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      totalPages: int.tryParse(json['total_pages']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Servicio para gestionar el historial de viajes del conductor
/// 
/// NOTA: Redundante con ConductorRemoteDataSource.
/// Se mantiene por compatibilidad.
class ConductorTripsService {
  /// URL base del microservicio
  static String get _baseUrl => AppConfig.baseUrl;

  /// Obtener historial de viajes
  static Future<Map<String, dynamic>> getTripsHistory({
    required int conductorId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/conductor/get_historial.php?conductor_id=$conductorId&page=$page&limit=$limit',
      );

      print('Fetching trips history: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Request timeout after 10 seconds');
          throw Exception('Tiempo de espera agotado. Por favor, intenta de nuevo.');
        },
      );

      print('Trips response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('Trips response body length: ${response.body.length}');
        
        final Map<String, dynamic> data;
        try {
          data = json.decode(response.body) as Map<String, dynamic>;
          print('JSON decoded successfully. Success: ${data['success']}');
        } catch (e) {
          print('Error decoding JSON: $e');
          print('Response body: ${response.body}');
          return {
            'success': false,
            'viajes': <TripModel>[],
            'message': 'Error al procesar la respuesta del servidor',
          };
        }
        
        if (data['success'] == true) {
          print('Processing viajes list...');
          final viajesData = data['viajes'];
          
          if (viajesData == null) {
            print('Warning: viajes is null');
            return {
              'success': true,
              'viajes': <TripModel>[],
              'pagination': PaginationModel(page: 1, limit: 20, total: 0, totalPages: 0),
              'message': data['message'] ?? 'No hay viajes disponibles',
            };
          }

          final List<TripModel> viajesList = [];
          try {
            for (var item in (viajesData as List)) {
              try {
                final trip = TripModel.fromJson(item as Map<String, dynamic>);
                viajesList.add(trip);
              } catch (e) {
                print('Error parsing trip item: $e');
                print('Item: $item');
              }
            }
            print('Parsed ${viajesList.length} trips successfully');
          } catch (e) {
            print('Error processing viajes list: $e');
          }

          PaginationModel pagination;
          try {
            pagination = data['pagination'] != null
                ? PaginationModel.fromJson(data['pagination'] as Map<String, dynamic>)
                : PaginationModel(page: 1, limit: 20, total: 0, totalPages: 0);
          } catch (e) {
            print('Error parsing pagination: $e');
            pagination = PaginationModel(page: 1, limit: 20, total: 0, totalPages: 0);
          }

          return {
            'success': true,
            'viajes': viajesList,
            'pagination': pagination,
            'message': data['message'] ?? 'Historial obtenido exitosamente',
          };
        } else {
          return {
            'success': false,
            'viajes': <TripModel>[],
            'message': data['message'] ?? 'Error al obtener historial',
          };
        }
      } else {
        return {
          'success': false,
          'viajes': <TripModel>[],
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error en getTripsHistory: $e');
      return {
        'success': false,
        'viajes': <TripModel>[],
        'message': 'Error de conexiÃ³n: $e',
      };
    }
  }

  /// Obtener detalles de un viaje especÃ­fico
  static Future<Map<String, dynamic>> getTripDetails({
    required int conductorId,
    required int tripId,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/conductor/get_viaje_detalle.php?conductor_id=$conductorId&viaje_id=$tripId',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['viaje'] != null) {
          return {
            'success': true,
            'viaje': TripModel.fromJson(data['viaje']),
            'message': 'Detalles obtenidos exitosamente',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'No se encontrÃ³ el viaje',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error en getTripDetails: $e');
      return {
        'success': false,
        'message': 'Error de conexiÃ³n: $e',
      };
    }
  }
}

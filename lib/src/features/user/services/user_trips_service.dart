import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Modelo de viaje del usuario
class UserTripModel {
  final int id;
  final String tipoServicio;
  final String estado;
  final String origen;
  final String destino;
  final double? distanciaKm;
  final int? duracionMinutos;
  final double precioEstimado;
  final double precioFinal;
  final String metodoPago;
  final bool pagoConfirmado;
  final String? conductorNombre;
  final String? conductorApellido;
  final double? calificacionConductor;
  final int? calificacionDada; // Calificación que el usuario dio al conductor
  final String? comentarioDado;
  final DateTime? fechaSolicitud;
  final DateTime? fechaCompletado;

  UserTripModel({
    required this.id,
    required this.tipoServicio,
    required this.estado,
    required this.origen,
    required this.destino,
    this.distanciaKm,
    this.duracionMinutos,
    required this.precioEstimado,
    required this.precioFinal,
    required this.metodoPago,
    required this.pagoConfirmado,
    this.conductorNombre,
    this.conductorApellido,
    this.calificacionConductor,
    this.calificacionDada,
    this.comentarioDado,
    this.fechaSolicitud,
    this.fechaCompletado,
  });

  factory UserTripModel.fromJson(Map<String, dynamic> json) {
    return UserTripModel(
      id: json['id'] ?? 0,
      tipoServicio: json['tipo_servicio'] ?? 'transporte',
      estado: json['estado'] ?? '',
      origen: json['origen'] ?? '',
      destino: json['destino'] ?? '',
      distanciaKm: json['distancia_km']?.toDouble(),
      // Usar duracion_minutos (real) o duracion_estimada como fallback
      duracionMinutos: json['duracion_minutos'] ?? json['duracion_estimada'],
      precioEstimado: (json['precio_estimado'] ?? 0).toDouble(),
      precioFinal: (json['precio_final'] ?? 0).toDouble(),
      metodoPago: json['metodo_pago'] ?? 'efectivo',
      pagoConfirmado: json['pago_confirmado'] ?? false,
      conductorNombre: json['conductor_nombre'],
      conductorApellido: json['conductor_apellido'],
      calificacionConductor: json['calificacion_conductor']?.toDouble(),
      calificacionDada: json['calificacion_dada'],
      comentarioDado: json['comentario_dado'],
      fechaSolicitud: json['fecha_solicitud'] != null 
          ? DateTime.tryParse(json['fecha_solicitud']) 
          : null,
      fechaCompletado: json['fecha_completado'] != null 
          ? DateTime.tryParse(json['fecha_completado']) 
          : null,
    );
  }

  String get conductorNombreCompleto {
    if (conductorNombre == null) return 'Sin asignar';
    return '${conductorNombre ?? ''} ${conductorApellido ?? ''}'.trim();
  }

  String get estadoFormateado {
    switch (estado) {
      case 'completada':
      case 'entregado':
        return 'Completado';
      case 'cancelada':
        return 'Cancelado';
      case 'en_curso':
      case 'en_transito':
        return 'En curso';
      case 'pendiente':
        return 'Pendiente';
      default:
        return estado;
    }
  }

  bool get isCompletado => estado == 'completada' || estado == 'entregado';
  bool get isCancelado => estado == 'cancelada';
}

/// Resumen de pagos del usuario
class UserPaymentSummary {
  final double totalPagado;
  final int totalViajes;
  final double promedioPorViaje;

  UserPaymentSummary({
    required this.totalPagado,
    required this.totalViajes,
    required this.promedioPorViaje,
  });
}

/// Servicio para obtener historial de viajes del usuario
class UserTripsService {
  static String get baseUrl => '${AppConfig.baseUrl}/user';

  /// Obtener historial de viajes del usuario
  static Future<Map<String, dynamic>> getHistorial({
    required int userId,
    int page = 1,
    int limit = 20,
    String? estado,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      var uri = '$baseUrl/get_trip_history.php?usuario_id=$userId&page=$page&limit=$limit';
      if (estado != null && estado != 'all') {
        uri += '&estado=$estado';
      }
      if (fechaInicio != null) {
        uri += '&fecha_inicio=${fechaInicio.toIso8601String().split('T')[0]}';
      }
      if (fechaFin != null) {
        uri += '&fecha_fin=${fechaFin.toIso8601String().split('T')[0]}';
      }

      final response = await http.get(
        Uri.parse(uri),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final viajes = (data['viajes'] as List?)
              ?.map((v) => UserTripModel.fromJson(v))
              .toList() ?? [];
          
          return {
            'success': true,
            'viajes': viajes,
            'pagination': data['pagination'],
          };
        }
      }
      return {'success': false, 'viajes': <UserTripModel>[]};
    } catch (e) {
      print('Error obteniendo historial de viajes: $e');
      return {'success': false, 'viajes': <UserTripModel>[], 'error': e.toString()};
    }
  }

  /// Obtener resumen de pagos del usuario
  static Future<UserPaymentSummary?> getPaymentSummary({
    required int userId,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    try {
      var uri = '$baseUrl/get_payment_summary.php?usuario_id=$userId';
      if (fechaInicio != null) uri += '&fecha_inicio=$fechaInicio';
      if (fechaFin != null) uri += '&fecha_fin=$fechaFin';

      final response = await http.get(
        Uri.parse(uri),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return UserPaymentSummary(
            totalPagado: (data['total_pagado'] ?? 0).toDouble(),
            totalViajes: data['total_viajes'] ?? 0,
            promedioPorViaje: (data['promedio_por_viaje'] ?? 0).toDouble(),
          );
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo resumen de pagos: $e');
      return null;
    }
  }
}

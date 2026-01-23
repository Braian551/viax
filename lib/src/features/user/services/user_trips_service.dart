import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Modelo para el desglose de precio de un viaje (para el usuario)
class UserPriceBreakdownModel {
  final double tarifaBase;
  final double precioDistancia;
  final double precioTiempo;
  final double recargoNocturno;
  final double recargoHoraPico;
  final double recargoFestivo;
  final double recargoEspera;
  final double tiempoEsperaMinutos;
  final double precioFinal;

  UserPriceBreakdownModel({
    this.tarifaBase = 0,
    this.precioDistancia = 0,
    this.precioTiempo = 0,
    this.recargoNocturno = 0,
    this.recargoHoraPico = 0,
    this.recargoFestivo = 0,
    this.recargoEspera = 0,
    this.tiempoEsperaMinutos = 0,
    this.precioFinal = 0,
  });

  factory UserPriceBreakdownModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return UserPriceBreakdownModel();
    
    double parseDouble(dynamic value) {
      if (value == null) return 0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return UserPriceBreakdownModel(
      tarifaBase: parseDouble(json['tarifa_base']),
      precioDistancia: parseDouble(json['precio_distancia']),
      precioTiempo: parseDouble(json['precio_tiempo']),
      recargoNocturno: parseDouble(json['recargo_nocturno']),
      recargoHoraPico: parseDouble(json['recargo_hora_pico']),
      recargoFestivo: parseDouble(json['recargo_festivo']),
      recargoEspera: parseDouble(json['recargo_espera']),
      tiempoEsperaMinutos: parseDouble(json['tiempo_espera_minutos']),
      precioFinal: parseDouble(json['precio_final']),
    );
  }

  /// Indica si hay algún recargo aplicado
  bool get tieneRecargos => 
      recargoNocturno > 0 || 
      recargoHoraPico > 0 || 
      recargoFestivo > 0 || 
      recargoEspera > 0;

  /// Total de recargos
  double get totalRecargos =>
      recargoNocturno + recargoHoraPico + recargoFestivo + recargoEspera;
}

/// Modelo de información del vehículo
class VehicleInfoModel {
  final String? placa;
  final String? marca;
  final String? modelo;
  final String? color;

  VehicleInfoModel({
    this.placa,
    this.marca,
    this.modelo,
    this.color,
  });

  factory VehicleInfoModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VehicleInfoModel();
    return VehicleInfoModel(
      placa: json['placa']?.toString(),
      marca: json['marca']?.toString(),
      modelo: json['modelo']?.toString(),
      color: json['color']?.toString(),
    );
  }

  String get descripcion {
    final parts = <String>[];
    if (marca != null && marca!.isNotEmpty) parts.add(marca!);
    if (modelo != null && modelo!.isNotEmpty) parts.add(modelo!);
    if (color != null && color!.isNotEmpty) parts.add('($color)');
    return parts.isEmpty ? '' : parts.join(' ');
  }
}

/// Modelo de viaje del usuario
class UserTripModel {
  final int id;
  final String tipoServicio;
  final String? tipoVehiculo;
  final String estado;
  final String origen;
  final String destino;
  final double? distanciaKm;
  final double? distanciaEstimada;
  final int? duracionMinutos;
  final int? duracionEstimada;
  final double precioEstimado;
  final double precioFinal;
  final UserPriceBreakdownModel? desglosePrecio;
  final String metodoPago;
  final bool pagoConfirmado;
  final int? conductorId;
  final String? conductorNombre;
  final String? conductorApellido;
  final String? conductorFoto;
  final String? conductorTelefono;
  final double? calificacionConductor;
  final VehicleInfoModel? vehiculo;
  final int? calificacionDada;
  final String? comentarioDado;
  final DateTime? fechaSolicitud;
  final DateTime? fechaAceptado;
  final DateTime? fechaCompletado;

  UserTripModel({
    required this.id,
    required this.tipoServicio,
    this.tipoVehiculo,
    required this.estado,
    required this.origen,
    required this.destino,
    this.distanciaKm,
    this.distanciaEstimada,
    this.duracionMinutos,
    this.duracionEstimada,
    required this.precioEstimado,
    required this.precioFinal,
    this.desglosePrecio,
    required this.metodoPago,
    required this.pagoConfirmado,
    this.conductorId,
    this.conductorNombre,
    this.conductorApellido,
    this.conductorFoto,
    this.conductorTelefono,
    this.calificacionConductor,
    this.vehiculo,
    this.calificacionDada,
    this.comentarioDado,
    this.fechaSolicitud,
    this.fechaAceptado,
    this.fechaCompletado,
  });

  factory UserTripModel.fromJson(Map<String, dynamic> json) {
    // Parsear desglose de precio si existe
    UserPriceBreakdownModel? desglose;
    if (json['desglose_precio'] != null) {
      final desgloseData = json['desglose_precio'];
      if (desgloseData is Map<String, dynamic>) {
        desglose = UserPriceBreakdownModel.fromJson(desgloseData);
      } else if (desgloseData is String) {
        try {
          final parsed = jsonDecode(desgloseData);
          if (parsed is Map<String, dynamic>) {
            desglose = UserPriceBreakdownModel.fromJson(parsed);
          }
        } catch (_) {}
      }
    }

    // Parsear info del vehículo
    VehicleInfoModel? vehiculo;
    if (json['vehiculo'] != null && json['vehiculo'] is Map<String, dynamic>) {
      vehiculo = VehicleInfoModel.fromJson(json['vehiculo']);
    }

    return UserTripModel(
      id: json['id'] ?? 0,
      tipoServicio: json['tipo_servicio'] ?? 'transporte',
      tipoVehiculo: json['tipo_vehiculo']?.toString(),
      estado: json['estado'] ?? '',
      origen: json['origen'] ?? '',
      destino: json['destino'] ?? '',
      distanciaKm: json['distancia_km']?.toDouble(),
      distanciaEstimada: json['distancia_estimada']?.toDouble(),
      duracionMinutos: json['duracion_minutos'] ?? json['duracion_estimada'],
      duracionEstimada: json['duracion_estimada'],
      precioEstimado: (json['precio_estimado'] ?? 0).toDouble(),
      precioFinal: (json['precio_final'] ?? 0).toDouble(),
      desglosePrecio: desglose,
      metodoPago: json['metodo_pago'] ?? 'efectivo',
      pagoConfirmado: json['pago_confirmado'] ?? false,
      conductorId: json['conductor_id'],
      conductorNombre: json['conductor_nombre'],
      conductorApellido: json['conductor_apellido'],
      conductorFoto: json['conductor_foto'],
      conductorTelefono: json['conductor_telefono'],
      calificacionConductor: json['calificacion_conductor']?.toDouble(),
      vehiculo: vehiculo,
      calificacionDada: json['calificacion_dada'],
      comentarioDado: json['comentario_dado'],
      fechaSolicitud: json['fecha_solicitud'] != null 
          ? DateTime.tryParse(json['fecha_solicitud']) 
          : null,
      fechaAceptado: json['fecha_aceptado'] != null 
          ? DateTime.tryParse(json['fecha_aceptado']) 
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

  bool get isCompletado => 
      estado == 'completada' || 
      estado == 'completado' || 
      estado == 'entregado' || 
      estado == 'finalizada' || 
      estado == 'finalizado';

  bool get isCancelado => 
      estado == 'cancelada' || 
      estado == 'cancelado';
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

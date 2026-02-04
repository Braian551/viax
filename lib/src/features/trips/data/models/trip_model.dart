import '../../domain/entities/trip.dart';
import '../../../../core/utils/date_time_utils.dart';

/// Modelo de Datos (DTO) para Trip
/// 
/// Extiende la entidad de dominio y aÃ±ade mÃ©todos de serializaciÃ³n.
class TripModel extends Trip {
  const TripModel({
    required super.id,
    required super.usuarioId,
    super.conductorId,
    required super.tipoServicio,
    required super.estado,
    required super.origen,
    required super.destino,
    super.precioEstimado,
    super.precioFinal,
    super.distanciaKm,
    super.duracionEstimadaMinutos,
    required super.fechaSolicitud,
    super.fechaAceptacion,
    super.fechaInicio,
    super.fechaFin,
    super.calificacionConductor,
    super.calificacionUsuario,
    super.comentarioConductor,
    super.comentarioUsuario,
    super.motivoCancelacion,
  });

  /// Crear desde JSON (API response)
  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: _parseInt(json['id'])!,
      usuarioId: _parseInt(json['usuario_id'])!,
      conductorId: _parseInt(json['conductor_id']),
      tipoServicio: TripType.fromString(json['tipo_servicio'] ?? 'motocicleta'),
      estado: TripStatus.fromString(json['estado'] ?? 'pendiente'),
      origen: TripLocationModel.fromJson(json['origen']),
      destino: TripLocationModel.fromJson(json['destino']),
      precioEstimado: _parseDouble(json['precio_estimado']),
      precioFinal: _parseDouble(json['precio_final']),
      distanciaKm: _parseDouble(json['distancia_km']),
      duracionEstimadaMinutos: _parseInt(json['duracion_estimada_minutos']),
      // Usar DateTimeUtils para parsear fechas del servidor (UTC) a hora local
      fechaSolicitud: DateTimeUtils.parseServerDateOrNow(json['fecha_solicitud']),
      fechaAceptacion: DateTimeUtils.parseServerDate(json['fecha_aceptacion']),
      fechaInicio: DateTimeUtils.parseServerDate(json['fecha_inicio']),
      fechaFin: DateTimeUtils.parseServerDate(json['fecha_fin']),
      calificacionConductor: _parseInt(json['calificacion_conductor']),
      calificacionUsuario: _parseInt(json['calificacion_usuario']),
      comentarioConductor: json['comentario_conductor'],
      comentarioUsuario: json['comentario_usuario'],
      motivoCancelacion: json['motivo_cancelacion'],
    );
  }

  /// Convertir a JSON (para enviar al API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'conductor_id': conductorId,
      'tipo_servicio': tipoServicio.name,
      'estado': estado.name,
      'origen': (origen as TripLocationModel).toJson(),
      'destino': (destino as TripLocationModel).toJson(),
      'precio_estimado': precioEstimado,
      'precio_final': precioFinal,
      'distancia_km': distanciaKm,
      'duracion_estimada_minutos': duracionEstimadaMinutos,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'fecha_aceptacion': fechaAceptacion?.toIso8601String(),
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'calificacion_conductor': calificacionConductor,
      'calificacion_usuario': calificacionUsuario,
      'comentario_conductor': comentarioConductor,
      'comentario_usuario': comentarioUsuario,
      'motivo_cancelacion': motivoCancelacion,
    };
  }

  /// Helpers para parsing
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// Modelo para TripLocation
class TripLocationModel extends TripLocation {
  const TripLocationModel({
    required super.direccion,
    required super.latitud,
    required super.longitud,
    super.referencia,
  });

  factory TripLocationModel.fromJson(Map<String, dynamic> json) {
    return TripLocationModel(
      direccion: json['direccion'] ?? '',
      latitud: _parseDouble(json['latitud']),
      longitud: _parseDouble(json['longitud']),
      referencia: json['referencia'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'referencia': referencia,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

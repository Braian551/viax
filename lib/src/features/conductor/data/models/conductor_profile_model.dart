import '../../domain/entities/conductor_profile.dart';
import 'package:viax/src/core/utils/colombian_plate_utils.dart';

/// Modelo de datos para ConductorProfile
/// 
/// Extiende la entidad del dominio y agrega capacidades de serializaciÃ³n.
/// Separa la lÃ³gica de negocio (entity) de los detalles de persistencia (model).
/// 
/// PATRÃ“N: Data Transfer Object (DTO)
/// - Convierte entre JSON (API/BD) y objetos Dart
/// - La entidad pura no conoce de JSON, HTTP, etc.
class ConductorProfileModel extends ConductorProfile {
  const ConductorProfileModel({
    required super.id,
    required super.conductorId,
    super.nombreCompleto,
    super.telefono,
    super.direccion,
    super.license,
    super.vehicle,
    super.aprobado,
    super.motivoRechazo,
    super.fechaAprobacion,
    super.fechaCreacion,
    super.fechaActualizacion,
  });

  /// Crea un modelo desde JSON (API response)
  factory ConductorProfileModel.fromJson(Map<String, dynamic> json) {
    return ConductorProfileModel(
      id: json['id'] as int? ?? 0,
      conductorId: json['conductor_id'] as int? ?? 0,
      nombreCompleto: json['nombre_completo'] as String?,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      license: json['licencia'] != null
          ? DriverLicenseModel.fromJson(json['licencia'] as Map<String, dynamic>)
          : null,
      vehicle: json['vehiculo'] != null
          ? VehicleModel.fromJson(json['vehiculo'] as Map<String, dynamic>)
          : null,
      aprobado: json['aprobado'] == 1 || json['aprobado'] == true,
      motivoRechazo: json['motivo_rechazo'] as String?,
      fechaAprobacion: json['fecha_aprobacion'] != null
          ? DateTime.tryParse(json['fecha_aprobacion'].toString())
          : null,
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.tryParse(json['fecha_creacion'].toString())
          : null,
      fechaActualizacion: json['fecha_actualizacion'] != null
          ? DateTime.tryParse(json['fecha_actualizacion'].toString())
          : null,
    );
  }

  /// Convierte el modelo a JSON (para enviar a API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conductor_id': conductorId,
      'nombre_completo': nombreCompleto,
      'telefono': telefono,
      'direccion': direccion,
      'licencia': license != null && license is DriverLicenseModel
          ? (license as DriverLicenseModel).toJson()
          : null,
      'vehiculo': vehicle != null && vehicle is VehicleModel
          ? (vehicle as VehicleModel).toJson()
          : null,
      'aprobado': aprobado ? 1 : 0,
      'motivo_rechazo': motivoRechazo,
      'fecha_aprobacion': fechaAprobacion?.toIso8601String(),
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  /// Crea un modelo a partir de una entidad
  factory ConductorProfileModel.fromEntity(ConductorProfile entity) {
    return ConductorProfileModel(
      id: entity.id,
      conductorId: entity.conductorId,
      nombreCompleto: entity.nombreCompleto,
      telefono: entity.telefono,
      direccion: entity.direccion,
      license: entity.license,
      vehicle: entity.vehicle,
      aprobado: entity.aprobado,
      motivoRechazo: entity.motivoRechazo,
      fechaAprobacion: entity.fechaAprobacion,
      fechaCreacion: entity.fechaCreacion,
      fechaActualizacion: entity.fechaActualizacion,
    );
  }
}

/// Modelo de datos para DriverLicense
class DriverLicenseModel extends DriverLicense {
  const DriverLicenseModel({
    super.numero,
    super.tipo,
    super.fechaEmision,
    super.fechaExpiracion,
    super.imagenFrente,
    super.imagenReverso,
  });

  factory DriverLicenseModel.fromJson(Map<String, dynamic> json) {
    return DriverLicenseModel(
      numero: json['numero'] as String?,
      tipo: json['tipo'] as String?,
      fechaEmision: json['fecha_emision'] != null
          ? DateTime.tryParse(json['fecha_emision'].toString())
          : null,
      fechaExpiracion: json['fecha_expiracion'] != null
          ? DateTime.tryParse(json['fecha_expiracion'].toString())
          : null,
      imagenFrente: json['imagen_frente'] as String?,
      imagenReverso: json['imagen_reverso'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'tipo': tipo,
      'fecha_emision': fechaEmision?.toIso8601String(),
      'fecha_expiracion': fechaExpiracion?.toIso8601String(),
      'imagen_frente': imagenFrente,
      'imagen_reverso': imagenReverso,
    };
  }

  factory DriverLicenseModel.fromEntity(DriverLicense entity) {
    return DriverLicenseModel(
      numero: entity.numero,
      tipo: entity.tipo,
      fechaEmision: entity.fechaEmision,
      fechaExpiracion: entity.fechaExpiracion,
      imagenFrente: entity.imagenFrente,
      imagenReverso: entity.imagenReverso,
    );
  }
}

/// Modelo de datos para Vehicle
class VehicleModel extends Vehicle {
  const VehicleModel({
    super.marca,
    super.modelo,
    super.anio,
    super.placa,
    super.color,
    super.capacidadPasajeros,
    super.tipo,
    super.imagenFrontal,
    super.imagenLateral,
    super.imagenTrasera,
    super.imagenInterior,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      anio: json['anio'] as int?,
      placa: ColombianPlateUtils.normalize((json['placa'] as String?) ?? ''),
      color: json['color'] as String?,
      capacidadPasajeros: json['capacidad_pasajeros'] as int?,
      tipo: json['tipo'] as String?,
      imagenFrontal: json['imagen_frontal'] as String?,
      imagenLateral: json['imagen_lateral'] as String?,
      imagenTrasera: json['imagen_trasera'] as String?,
      imagenInterior: json['imagen_interior'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'placa': ColombianPlateUtils.normalize(placa ?? ''),
      'color': color,
      'capacidad_pasajeros': capacidadPasajeros,
      'tipo': tipo,
      'imagen_frontal': imagenFrontal,
      'imagen_lateral': imagenLateral,
      'imagen_trasera': imagenTrasera,
      'imagen_interior': imagenInterior,
    };
  }

  String get placaFormateada =>
      ColombianPlateUtils.formatForDisplay(placa, fallback: '---');

  factory VehicleModel.fromEntity(Vehicle entity) {
    return VehicleModel(
      marca: entity.marca,
      modelo: entity.modelo,
      anio: entity.anio,
      placa: entity.placa,
      color: entity.color,
      capacidadPasajeros: entity.capacidadPasajeros,
      tipo: entity.tipo,
      imagenFrontal: entity.imagenFrontal,
      imagenLateral: entity.imagenLateral,
      imagenTrasera: entity.imagenTrasera,
      imagenInterior: entity.imagenInterior,
    );
  }
}

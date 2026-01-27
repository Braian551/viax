import 'driver_license_model.dart';
import 'vehicle_model.dart';

/// Modelo para el perfil completo del conductor
class ConductorProfileModel {
  final DriverLicenseModel? licencia;
  final VehicleModel? vehiculo;
  final VerificationStatus estadoVerificacion;
  final DateTime? fechaUltimaVerificacion;
  final List<String> documentosPendientes;
  final List<String> documentosRechazados;
  final String? motivoRechazo;
  final bool aprobado;

  final int viajes;
  final DateTime? fechaRegistro;
  final double calificacionPromedio;
  final int totalCalificaciones;
  
  /// Foto de perfil del conductor (key de R2)
  final String? fotoPerfil;

  ConductorProfileModel({
    this.licencia,
    this.vehiculo,
    this.estadoVerificacion = VerificationStatus.pendiente,
    this.fechaUltimaVerificacion,
    this.documentosPendientes = const [],
    this.documentosRechazados = const [],
    this.motivoRechazo,
    this.aprobado = false,
    this.viajes = 0,
    this.fechaRegistro,
    this.calificacionPromedio = 5.0,
    this.totalCalificaciones = 0,
    this.fotoPerfil,
  });

  factory ConductorProfileModel.fromJson(Map<String, dynamic> json) {
    return ConductorProfileModel(
      licencia: json['licencia'] != null
          ? DriverLicenseModel.fromJson(json['licencia'])
          : null,
      vehiculo: json['vehiculo'] != null
          ? VehicleModel.fromJson(json['vehiculo'])
          : null,
      estadoVerificacion: VerificationStatus.fromString(
        json['estado_verificacion']?.toString() ?? 'pendiente',
      ),
      fechaUltimaVerificacion: json['fecha_ultima_verificacion'] != null
          ? DateTime.tryParse(json['fecha_ultima_verificacion'].toString())
          : null,
      documentosPendientes: json['documentos_pendientes'] != null
          ? List<String>.from(json['documentos_pendientes'])
          : [],
      documentosRechazados: json['documentos_rechazados'] != null
          ? List<String>.from(json['documentos_rechazados'])
          : [],
      motivoRechazo: json['motivo_rechazo']?.toString(),
      aprobado: json['aprobado'] == 1 || json['aprobado'] == true,
      viajes: int.tryParse(json['viajes']?.toString() ?? '0') ?? 0,
      fechaRegistro: json['fecha_registro'] != null
          ? DateTime.tryParse(json['fecha_registro'].toString())
          : null,
      calificacionPromedio: double.tryParse(json['calificacion_promedio']?.toString() ?? '5.0') ?? 5.0,
      totalCalificaciones: int.tryParse(json['total_calificaciones']?.toString() ?? '0') ?? 0,
      fotoPerfil: json['foto_perfil']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'licencia': licencia?.toJson(),
      'vehiculo': vehiculo?.toJson(),
      'estado_verificacion': estadoVerificacion.value,
      'fecha_ultima_verificacion': fechaUltimaVerificacion?.toIso8601String(),
      'documentos_pendientes': documentosPendientes,
      'documentos_rechazados': documentosRechazados,
      'motivo_rechazo': motivoRechazo,
      'aprobado': aprobado ? 1 : 0,
      'viajes': viajes,
      'fecha_registro': fechaRegistro?.toIso8601String(),
      'calificacion_promedio': calificacionPromedio,
      'total_calificaciones': totalCalificaciones,
      'foto_perfil': fotoPerfil,
    };
  }

  /// Verifica si el perfil estÃ¡ completo
  bool get isProfileComplete {
    return licencia != null &&
        licencia!.isComplete &&
        vehiculo != null &&
        vehiculo!.isComplete;
  }

  /// Verifica si hay documentos pendientes de subir
  bool get hasPendingDocuments {
    return documentosPendientes.isNotEmpty;
  }

  /// Verifica si hay documentos rechazados
  bool get hasRejectedDocuments {
    return documentosRechazados.isNotEmpty;
  }

  /// Verifica si el conductor puede estar disponible
  bool get canBeAvailable {
    return aprobado &&
        estadoVerificacion == VerificationStatus.aprobado &&
        isProfileComplete &&
        !hasPendingDocuments &&
        !hasRejectedDocuments;
  }

  /// Obtiene el porcentaje de completitud del perfil
  double get completionPercentage {
    int total = 0;
    int completed = 0;

    // Licencia (40%)
    total += 40;
    if (licencia != null && licencia!.isComplete) {
      completed += 40;
    } else if (licencia != null) {
      completed += 20;
    }

    // VehÃ­culo (40%)
    total += 40;
    if (vehiculo != null && vehiculo!.isBasicComplete) {
      completed += 20;
    }
    if (vehiculo != null && vehiculo!.isDocumentsComplete) {
      completed += 20;
    }

    // VerificaciÃ³n (20%)
    total += 20;
    if (estadoVerificacion == VerificationStatus.aprobado) {
      completed += 20;
    } else if (estadoVerificacion == VerificationStatus.enRevision) {
      completed += 10;
    }

    return completed / total;
  }

  /// Lista de tareas pendientes para completar el perfil
  List<String> get pendingTasks {
    List<String> tasks = [];

    if (licencia == null || !licencia!.isComplete) {
      tasks.add('Registrar licencia de conducciÃ³n');
    } else if (licencia!.isExpiringSoon) {
      tasks.add('Renovar licencia de conducciÃ³n (vence pronto)');
    } else if (!licencia!.isValid) {
      tasks.add('Renovar licencia de conducciÃ³n (vencida)');
    }

    if (vehiculo == null || !vehiculo!.isBasicComplete) {
      tasks.add('Registrar informaciÃ³n del vehÃ­culo');
    }

    if (vehiculo != null && !vehiculo!.isDocumentsComplete) {
      tasks.add('Completar documentos del vehÃ­culo');
    }

    if (documentosPendientes.isNotEmpty) {
      tasks.addAll(documentosPendientes.map((doc) => 'Subir $doc'));
    }

    if (documentosRechazados.isNotEmpty) {
      tasks.addAll(
        documentosRechazados.map((doc) => 'Corregir y volver a subir $doc'),
      );
    }

    if (estadoVerificacion == VerificationStatus.pendiente && isProfileComplete) {
      tasks.add('Esperar verificaciÃ³n de documentos');
    }

    return tasks;
  }

  ConductorProfileModel copyWith({
    DriverLicenseModel? licencia,
    VehicleModel? vehiculo,
    VerificationStatus? estadoVerificacion,
    DateTime? fechaUltimaVerificacion,
    List<String>? documentosPendientes,
    List<String>? documentosRechazados,
    String? motivoRechazo,
    bool? aprobado,
    int? viajes,
    DateTime? fechaRegistro,
    double? calificacionPromedio,
    int? totalCalificaciones,
    String? fotoPerfil,
  }) {
    return ConductorProfileModel(
      licencia: licencia ?? this.licencia,
      vehiculo: vehiculo ?? this.vehiculo,
      estadoVerificacion: estadoVerificacion ?? this.estadoVerificacion,
      fechaUltimaVerificacion: fechaUltimaVerificacion ?? this.fechaUltimaVerificacion,
      documentosPendientes: documentosPendientes ?? this.documentosPendientes,
      documentosRechazados: documentosRechazados ?? this.documentosRechazados,
      motivoRechazo: motivoRechazo ?? this.motivoRechazo,
      aprobado: aprobado ?? this.aprobado,
      viajes: viajes ?? this.viajes,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      totalCalificaciones: totalCalificaciones ?? this.totalCalificaciones,
      fotoPerfil: fotoPerfil ?? this.fotoPerfil,
    );
  }
}

/// Estado de verificaciÃ³n del perfil del conductor
enum VerificationStatus {
  pendiente('pendiente', 'Pendiente', 'â³'),
  enRevision('en_revision', 'En RevisiÃ³n', 'ðŸ”'),
  aprobado('aprobado', 'Aprobado', 'âœ…'),
  rechazado('rechazado', 'Rechazado', 'âŒ');

  final String value;
  final String label;
  final String emoji;

  const VerificationStatus(this.value, this.label, this.emoji);

  static VerificationStatus fromString(String value) {
    return VerificationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => VerificationStatus.pendiente,
    );
  }
}

/// Modelo para información de confianza de un conductor
/// 
/// Contiene datos sobre el nivel de confianza entre un usuario y un conductor
class ConfianzaInfo {
  final double score;
  final double scoreTotal;
  final int viajesPrevios;
  final bool esFavorito;

  const ConfianzaInfo({
    this.score = 0,
    this.scoreTotal = 0,
    this.viajesPrevios = 0,
    this.esFavorito = false,
  });

  factory ConfianzaInfo.fromJson(Map<String, dynamic> json) {
    return ConfianzaInfo(
      score: (json['score'] ?? 0).toDouble(),
      scoreTotal: (json['score_total'] ?? 0).toDouble(),
      viajesPrevios: json['viajes_previos'] ?? 0,
      esFavorito: json['es_favorito'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'score_total': scoreTotal,
      'viajes_previos': viajesPrevios,
      'es_favorito': esFavorito,
    };
  }

  /// Obtiene el nivel de confianza basado en el score
  NivelConfianza get nivel {
    if (scoreTotal >= 150) return NivelConfianza.muyAlto;
    if (scoreTotal >= 100) return NivelConfianza.alto;
    if (scoreTotal >= 50) return NivelConfianza.medio;
    if (scoreTotal >= 20) return NivelConfianza.bajo;
    return NivelConfianza.nuevo;
  }

  /// Descripción del nivel de confianza
  String get descripcion {
    switch (nivel) {
      case NivelConfianza.muyAlto:
        return 'Conductor de extrema confianza';
      case NivelConfianza.alto:
        return 'Conductor favorito o muy confiable';
      case NivelConfianza.medio:
        return 'Conductor conocido';
      case NivelConfianza.bajo:
        return 'Algunos viajes previos';
      case NivelConfianza.nuevo:
        return 'Sin historial';
    }
  }
}

enum NivelConfianza {
  nuevo,
  bajo,
  medio,
  alto,
  muyAlto,
}

/// Modelo para un conductor favorito
class ConductorFavorito {
  final int conductorId;
  final String nombre;
  final String apellido;
  final String? fotoPerfil;
  final VehiculoInfo vehiculo;
  final double calificacionPromedio;
  final int totalViajes;
  final int viajesContigo;
  final double scoreConfianza;
  final DateTime? fechaMarcado;

  const ConductorFavorito({
    required this.conductorId,
    required this.nombre,
    required this.apellido,
    this.fotoPerfil,
    required this.vehiculo,
    this.calificacionPromedio = 0,
    this.totalViajes = 0,
    this.viajesContigo = 0,
    this.scoreConfianza = 0,
    this.fechaMarcado,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  factory ConductorFavorito.fromJson(Map<String, dynamic> json) {
    return ConductorFavorito(
      conductorId: json['conductor_id'] ?? 0,
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      fotoPerfil: json['foto_perfil'],
      vehiculo: VehiculoInfo.fromJson(json['vehiculo'] ?? {}),
      calificacionPromedio: (json['calificacion_promedio'] ?? 0).toDouble(),
      totalViajes: json['total_viajes'] ?? 0,
      viajesContigo: json['viajes_contigo'] ?? 0,
      scoreConfianza: (json['score_confianza'] ?? 0).toDouble(),
      fechaMarcado: json['fecha_marcado'] != null 
          ? DateTime.tryParse(json['fecha_marcado']) 
          : null,
    );
  }
}

class VehiculoInfo {
  final String tipo;
  final String? marca;
  final String? modelo;
  final String? placa;

  const VehiculoInfo({
    required this.tipo,
    this.marca,
    this.modelo,
    this.placa,
  });

  factory VehiculoInfo.fromJson(Map<String, dynamic> json) {
    return VehiculoInfo(
      tipo: json['tipo'] ?? 'motocicleta',
      marca: json['marca'],
      modelo: json['modelo'],
      placa: json['placa'],
    );
  }

  String get descripcion {
    final parts = <String>[];
    if (marca != null) parts.add(marca!);
    if (modelo != null) parts.add(modelo!);
    return parts.isNotEmpty ? parts.join(' ') : tipo;
  }
}

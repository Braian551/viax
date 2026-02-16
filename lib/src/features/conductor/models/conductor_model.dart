import 'package:viax/src/core/utils/colombian_plate_utils.dart';

class ConductorModel {
  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final String telefono;
  final String? fotoPerfil;
  final double calificacionPromedio;
  final int totalViajes;
  final bool disponible;
  final String? vehiculoModelo;
  final String? vehiculoPlaca;
  final String? vehiculoColor;
  final String? licenciaNumero;
  final DateTime? licenciaVencimiento;
  final double? latitud;
  final double? longitud;

  ConductorModel({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.telefono,
    this.fotoPerfil,
    this.calificacionPromedio = 0.0,
    this.totalViajes = 0,
    this.disponible = false,
    this.vehiculoModelo,
    this.vehiculoPlaca,
    this.vehiculoColor,
    this.licenciaNumero,
    this.licenciaVencimiento,
    this.latitud,
    this.longitud,
  });

  factory ConductorModel.fromJson(Map<String, dynamic> json) {
    return ConductorModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nombre: json['nombre']?.toString() ?? '',
      apellido: json['apellido']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      fotoPerfil: json['foto_perfil']?.toString(),
      calificacionPromedio: double.tryParse(json['calificacion_promedio']?.toString() ?? '0') ?? 0.0,
      totalViajes: int.tryParse(json['total_viajes']?.toString() ?? '0') ?? 0,
      disponible: json['disponible'] == 1 || json['disponible'] == true,
      vehiculoModelo: json['vehiculo_modelo']?.toString(),
      vehiculoPlaca: ColombianPlateUtils.normalize(json['vehiculo_placa']?.toString() ?? ''),
      vehiculoColor: json['vehiculo_color']?.toString(),
      licenciaNumero: json['licencia_numero']?.toString(),
      licenciaVencimiento: json['licencia_vencimiento'] != null
          ? DateTime.tryParse(json['licencia_vencimiento'].toString())
          : null,
      latitud: double.tryParse(json['latitud']?.toString() ?? '0'),
      longitud: double.tryParse(json['longitud']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'telefono': telefono,
      'foto_perfil': fotoPerfil,
      'calificacion_promedio': calificacionPromedio,
      'total_viajes': totalViajes,
      'disponible': disponible ? 1 : 0,
      'vehiculo_modelo': vehiculoModelo,
      'vehiculo_placa': vehiculoPlaca,
      'vehiculo_color': vehiculoColor,
      'licencia_numero': licenciaNumero,
      'licencia_vencimiento': licenciaVencimiento?.toIso8601String(),
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  String get nombreCompleto => '$nombre $apellido';
  String get vehiculoPlacaFormateada =>
      ColombianPlateUtils.formatForDisplay(vehiculoPlaca, fallback: '---');
}

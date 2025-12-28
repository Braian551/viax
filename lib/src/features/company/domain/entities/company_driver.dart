/// Company Driver Entity
/// Domain entity representing a driver associated with a company

class CompanyDriver {
  final int id;
  final String nombre;
  final String apellido;
  final String? email;
  final String? telefono;
  final bool esActivo;
  final bool esVerificado;
  final String? tipoVehiculo;
  final String? vehiculoPlaca;
  final String? fechaRegistro;

  CompanyDriver({
    required this.id,
    required this.nombre,
    required this.apellido,
    this.email,
    this.telefono,
    this.esActivo = true,
    this.esVerificado = false,
    this.tipoVehiculo,
    this.vehiculoPlaca,
    this.fechaRegistro,
  });

  factory CompanyDriver.fromJson(Map<String, dynamic> json) {
    return CompanyDriver(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      email: json['email'],
      telefono: json['telefono'],
      esActivo: json['es_activo'] == 1,
      esVerificado: json['es_verificado'] == 1,
      tipoVehiculo: json['tipo_vehiculo'],
      vehiculoPlaca: json['vehiculo_placa'],
      fechaRegistro: json['fecha_registro'],
    );
  }

  String get fullName => '$nombre $apellido';
  
  String get initials => nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
}

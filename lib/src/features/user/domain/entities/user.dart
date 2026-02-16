/// Entidad de Dominio: User
/// 
/// Representa un usuario en el sistema (pasajero o conductor).
/// Esta clase es inmutable y no depende de ningÃºn framework.
/// 
/// PRINCIPIOS:
/// - Inmutable (usar copyWith para "modificar")
/// - Sin dependencias de Flutter/HTTP/BD
/// - Validaciones simples de negocio
/// - Parte del microservicio de autenticaciÃ³n/usuarios
class User {
  final int id;
  final String uuid;
  final String nombre;
  final String apellido;
  final String email;
  final String telefono;
  final UserType tipoUsuario;
  final DateTime creadoEn;
  final DateTime? actualizadoEn;
  final UserLocation? ubicacionPrincipal;
  final double? calificacion;

  const User({
    required this.id,
    required this.uuid,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.telefono,
    required this.tipoUsuario,
    required this.creadoEn,
    this.actualizadoEn,
    this.ubicacionPrincipal,
    this.calificacion,
  });

  /// Nombre completo del usuario
  String get nombreCompleto => '$nombre $apellido';

  /// ValidaciÃ³n: Email tiene formato vÃ¡lido
  bool get hasValidEmail => _emailRegex.hasMatch(email);

  /// ValidaciÃ³n: TelÃ©fono no estÃ¡ vacÃ­o
  bool get hasValidPhone => telefono.isNotEmpty;

  /// ValidaciÃ³n: Usuario tiene ubicaciÃ³n principal configurada
  bool get hasLocation => ubicacionPrincipal != null;

  /// ValidaciÃ³n: Perfil estÃ¡ completo
  bool get isProfileComplete {
    return hasValidEmail &&
        hasValidPhone &&
        nombre.isNotEmpty &&
        apellido.isNotEmpty;
  }

  /// Porcentaje de completitud del perfil (0-100)
  int get profileCompletionPercentage {
    int completed = 0;
    int total = 5;

    if (hasValidEmail) completed++;
    if (hasValidPhone) completed++;
    if (nombre.isNotEmpty) completed++;
    if (apellido.isNotEmpty) completed++;
    if (hasLocation) completed++;

    return ((completed / total) * 100).round();
  }

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Copia inmutable con cambios
  User copyWith({
    int? id,
    String? uuid,
    String? nombre,
    String? apellido,
    String? email,
    String? telefono,
    UserType? tipoUsuario,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    UserLocation? ubicacionPrincipal,
    double? calificacion,
  }) {
    return User(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      tipoUsuario: tipoUsuario ?? this.tipoUsuario,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      ubicacionPrincipal: ubicacionPrincipal ?? this.ubicacionPrincipal,
      calificacion: calificacion ?? this.calificacion,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is User &&
        other.id == id &&
        other.uuid == uuid &&
        other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ uuid.hashCode ^ email.hashCode;

  @override
  String toString() {
    return 'User(id: $id, nombreCompleto: $nombreCompleto, email: $email, tipo: $tipoUsuario)';
  }
}

/// Tipo de usuario en el sistema
enum UserType {
  pasajero('pasajero'),
  conductor('conductor'),
  admin('admin');

  final String value;
  const UserType(this.value);

  static UserType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'conductor':
        return UserType.conductor;
      case 'admin':
        return UserType.admin;
      case 'pasajero':
      default:
        return UserType.pasajero;
    }
  }
}

/// Entidad de Dominio: UserLocation
/// 
/// Representa una ubicaciÃ³n del usuario (direcciÃ³n guardada).
class UserLocation {
  final int id;
  final int usuarioId;
  final double? latitud;
  final double? longitud;
  final String? direccion;
  final String? ciudad;
  final String? departamento;
  final String? pais;
  final String? codigoPostal;
  final bool esPrincipal;
  final DateTime creadoEn;
  final DateTime? actualizadoEn;

  const UserLocation({
    required this.id,
    required this.usuarioId,
    this.latitud,
    this.longitud,
    this.direccion,
    this.ciudad,
    this.departamento,
    this.pais,
    this.codigoPostal,
    required this.esPrincipal,
    required this.creadoEn,
    this.actualizadoEn,
  });

  /// ValidaciÃ³n: Tiene coordenadas vÃ¡lidas
  bool get hasValidCoordinates =>
      latitud != null &&
      longitud != null &&
      latitud! >= -90 &&
      latitud! <= 90 &&
      longitud! >= -180 &&
      longitud! <= 180;

  /// DirecciÃ³n formateada para mostrar
  String get formattedAddress {
    final parts = <String>[];
    if (direccion != null && direccion!.isNotEmpty) parts.add(direccion!);
    if (ciudad != null && ciudad!.isNotEmpty) parts.add(ciudad!);
    if (departamento != null && departamento!.isNotEmpty) parts.add(departamento!);
    if (pais != null && pais!.isNotEmpty && pais != 'Colombia') parts.add(pais!);

    return parts.isEmpty ? 'Sin direcciÃ³n' : parts.join(', ');
  }

  UserLocation copyWith({
    int? id,
    int? usuarioId,
    double? latitud,
    double? longitud,
    String? direccion,
    String? ciudad,
    String? departamento,
    String? pais,
    String? codigoPostal,
    bool? esPrincipal,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return UserLocation(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      departamento: departamento ?? this.departamento,
      pais: pais ?? this.pais,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      esPrincipal: esPrincipal ?? this.esPrincipal,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  @override
  String toString() {
    return 'UserLocation(id: $id, direccion: $formattedAddress, esPrincipal: $esPrincipal)';
  }
}

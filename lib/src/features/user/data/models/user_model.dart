import 'package:viax/src/features/user/domain/entities/user.dart';
import 'package:viax/src/features/user/domain/entities/auth_session.dart';

/// Modelo de Datos: UserModel
/// 
/// DTO (Data Transfer Object) que extiende la entidad User.
/// Sabe cÃ³mo serializar/deserializar desde JSON.
/// 
/// RESPONSABILIDADES:
/// - ConversiÃ³n JSON <-> Objeto Dart
/// - Mapeo entre datos del backend y entidad de dominio
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.uuid,
    required super.nombre,
    required super.apellido,
    required super.email,
    required super.telefono,
    required super.tipoUsuario,
    required super.creadoEn,
    super.actualizadoEn,
    super.ubicacionPrincipal,
    super.calificacion,
  });

  /// Crear desde JSON (backend response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _parseInt(json['id']),
      uuid: json['uuid'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      email: json['email'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      tipoUsuario: UserType.fromString(
        json['tipo_usuario'] as String? ?? 'pasajero',
      ),
      creadoEn: _parseDateTime(json['creado_en']) ?? DateTime.now(),
      actualizadoEn: _parseDateTime(json['actualizado_en']),
      ubicacionPrincipal: json['location'] != null
          ? UserLocationModel.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      calificacion: _parseDouble(
        json['calificacion'] ?? 
        json['calificacion_promedio'] ?? 
        json['rating'] ?? 
        json['stars'],
      ),
    );
  }

  /// Convertir a JSON (para enviar al backend)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'telefono': telefono,
      'tipo_usuario': tipoUsuario.value,
      'creado_en': creadoEn.toIso8601String(),
      if (actualizadoEn != null)
        'actualizado_en': actualizadoEn!.toIso8601String(),
      if (ubicacionPrincipal != null)
        'location': (ubicacionPrincipal as UserLocationModel).toJson(),
      if (calificacion != null) 'calificacion': calificacion,
    };
  }

  /// Convertir a entidad de dominio
  User toEntity() {
    return User(
      id: id,
      uuid: uuid,
      nombre: nombre,
      apellido: apellido,
      email: email,
      telefono: telefono,
      tipoUsuario: tipoUsuario,
      creadoEn: creadoEn,
      actualizadoEn: actualizadoEn,
      ubicacionPrincipal: ubicacionPrincipal,
      calificacion: calificacion,
    );
  }

  /// Crear desde entidad de dominio
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      uuid: user.uuid,
      nombre: user.nombre,
      apellido: user.apellido,
      email: user.email,
      telefono: user.telefono,
      tipoUsuario: user.tipoUsuario,
      creadoEn: user.creadoEn,
      actualizadoEn: user.actualizadoEn,
      ubicacionPrincipal: user.ubicacionPrincipal,
      calificacion: user.calificacion,
    );
  }

  // Helpers para parsing robusto
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Modelo de Datos: UserLocationModel
class UserLocationModel extends UserLocation {
  const UserLocationModel({
    required super.id,
    required super.usuarioId,
    super.latitud,
    super.longitud,
    super.direccion,
    super.ciudad,
    super.departamento,
    super.pais,
    super.codigoPostal,
    required super.esPrincipal,
    required super.creadoEn,
    super.actualizadoEn,
  });

  factory UserLocationModel.fromJson(Map<String, dynamic> json) {
    return UserLocationModel(
      id: _parseInt(json['id']),
      usuarioId: _parseInt(json['usuario_id']),
      latitud: _parseDouble(json['latitud']),
      longitud: _parseDouble(json['longitud']),
      direccion: json['direccion'] as String?,
      ciudad: json['ciudad'] as String?,
      departamento: json['departamento'] as String?,
      pais: json['pais'] as String?,
      codigoPostal: json['codigo_postal'] as String?,
      esPrincipal: _parseBool(json['es_principal']),
      creadoEn: _parseDateTime(json['creado_en']) ?? DateTime.now(),
      actualizadoEn: _parseDateTime(json['actualizado_en']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      if (latitud != null) 'latitud': latitud,
      if (longitud != null) 'longitud': longitud,
      if (direccion != null) 'direccion': direccion,
      if (ciudad != null) 'ciudad': ciudad,
      if (departamento != null) 'departamento': departamento,
      if (pais != null) 'pais': pais,
      if (codigoPostal != null) 'codigo_postal': codigoPostal,
      'es_principal': esPrincipal ? 1 : 0,
      'creado_en': creadoEn.toIso8601String(),
      if (actualizadoEn != null)
        'actualizado_en': actualizadoEn!.toIso8601String(),
    };
  }

  UserLocation toEntity() {
    return UserLocation(
      id: id,
      usuarioId: usuarioId,
      latitud: latitud,
      longitud: longitud,
      direccion: direccion,
      ciudad: ciudad,
      departamento: departamento,
      pais: pais,
      codigoPostal: codigoPostal,
      esPrincipal: esPrincipal,
      creadoEn: creadoEn,
      actualizadoEn: actualizadoEn,
    );
  }

  // Helpers
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Modelo de Datos: AuthSessionModel
class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.user,
    super.token,
    super.tokenExpiresAt,
    required super.loginAt,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String?,
      tokenExpiresAt: _parseDateTime(json['token_expires_at']),
      loginAt: _parseDateTime(json['login_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': (user as UserModel).toJson(),
      if (token != null) 'token': token,
      if (tokenExpiresAt != null)
        'token_expires_at': tokenExpiresAt!.toIso8601String(),
      'login_at': loginAt.toIso8601String(),
    };
  }

  AuthSession toEntity() {
    return AuthSession(
      user: user,
      token: token,
      tokenExpiresAt: tokenExpiresAt,
      loginAt: loginAt,
    );
  }

  factory AuthSessionModel.fromEntity(AuthSession session) {
    return AuthSessionModel(
      user: session.user,
      token: session.token,
      tokenExpiresAt: session.tokenExpiresAt,
      loginAt: session.loginAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

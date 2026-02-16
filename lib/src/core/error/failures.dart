/// Clase base abstracta para representar fallos en la aplicaciÃ³n
/// 
/// Esta clase permite manejar errores de forma tipada y funcional,
/// separando la lÃ³gica de dominio de los detalles de implementaciÃ³n.
/// 
/// NOTA PARA MIGRACIÃ“N A MICROSERVICIOS:
/// - Estas clases de error pueden incluir cÃ³digos HTTP para API REST
/// - Facilita el manejo de errores distribuidos entre servicios
abstract class Failure {
  final String message;
  final int? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => message;
}

/// Fallo de servidor (API, Backend)
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.code]);
}

/// Fallo de conexiÃ³n (red, timeout)
class ConnectionFailure extends Failure {
  const ConnectionFailure(super.message);
}

/// Fallo de cache/base de datos local
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Fallo de validaciÃ³n (datos invÃ¡lidos)
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Fallo de autenticaciÃ³n
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.code]);
}

/// Fallo no autorizado (permisos)
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(String message) : super(message, 403);
}

/// Fallo de recurso no encontrado
class NotFoundFailure extends Failure {
  const NotFoundFailure(String message) : super(message, 404);
}

/// Fallo genÃ©rico/desconocido
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

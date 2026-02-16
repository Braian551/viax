/// Excepciones para la capa de datos
/// 
/// Estas excepciones se lanzan en datasources y se convierten
/// en Failures en la capa de repositorio.
/// 
/// NOTA: Las excepciones son para errores tÃ©cnicos/infraestructura,
/// los Failures son para la lÃ³gica de negocio.
library;

/// ExcepciÃ³n base
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Error del servidor (HTTP 500, 400, etc.)
class ServerException extends AppException {
  const ServerException(super.message);
}

/// Error de conexiÃ³n/red
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Recurso no encontrado (HTTP 404)
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Error de cachÃ©/BD local
class CacheException extends AppException {
  const CacheException(super.message);
}

/// Error de autenticaciÃ³n (HTTP 401)
class AuthException extends AppException {
  const AuthException(super.message);
}

/// Error de autorizaciÃ³n (HTTP 403)
class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message);
}

/// Error de validaciÃ³n de datos
class ValidationException extends AppException {
  const ValidationException(super.message);
}

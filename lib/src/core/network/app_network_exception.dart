import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Tipos de error de red que la UI puede interpretar de forma amigable.
enum AppNetworkErrorType {
  offline,
  timeout,
  serverUnavailable,
  unauthorized,
  noData,
  invalidResponse,
  business,
  unknown,
}

/// Excepción unificada para errores de red/API.
class AppNetworkException implements Exception {
  final AppNetworkErrorType type;
  final String technicalMessage;
  final String? backendMessage;
  final int? statusCode;

  const AppNetworkException({
    required this.type,
    required this.technicalMessage,
    this.backendMessage,
    this.statusCode,
  });

  String get userMessage {
    switch (type) {
      case AppNetworkErrorType.offline:
        return 'No tienes conexión a internet. Verifica tu red y vuelve a intentarlo.';
      case AppNetworkErrorType.timeout:
        return 'La conexión está lenta o inestable. Inténtalo nuevamente en unos segundos.';
      case AppNetworkErrorType.serverUnavailable:
        return 'El servicio no está disponible en este momento. Estamos trabajando para restablecerlo.';
      case AppNetworkErrorType.unauthorized:
        return 'Tu sesión no es válida o no tienes permisos para esta acción.';
      case AppNetworkErrorType.noData:
        return 'No pudimos obtener información del servidor. Intenta de nuevo.';
      case AppNetworkErrorType.invalidResponse:
        return 'Recibimos una respuesta inválida del servidor. Intenta nuevamente.';
      case AppNetworkErrorType.business:
        return (backendMessage != null && backendMessage!.trim().isNotEmpty)
            ? backendMessage!
            : 'No fue posible completar la operación.';
      case AppNetworkErrorType.unknown:
        return 'Ocurrió un problema inesperado. Intenta nuevamente.';
    }
  }

  static AppNetworkException fromError(
    Object error, {
    int? statusCode,
    String? backendMessage,
  }) {
    if (error is AppNetworkException) {
      return error;
    }

    if (error is TimeoutException) {
      return AppNetworkException(
        type: AppNetworkErrorType.timeout,
        technicalMessage: error.toString(),
      );
    }

    if (error is SocketException) {
      return AppNetworkException(
        type: AppNetworkErrorType.offline,
        technicalMessage: error.toString(),
      );
    }

    if (error is http.ClientException) {
      return AppNetworkException(
        type: AppNetworkErrorType.serverUnavailable,
        technicalMessage: error.message,
        statusCode: statusCode,
      );
    }

    return AppNetworkException(
      type: AppNetworkErrorType.unknown,
      technicalMessage: error.toString(),
      backendMessage: backendMessage,
      statusCode: statusCode,
    );
  }

  static AppNetworkException fromStatusCode(
    int statusCode, {
    String? technicalMessage,
    String? backendMessage,
  }) {
    if (statusCode == 401 || statusCode == 403) {
      return AppNetworkException(
        type: AppNetworkErrorType.unauthorized,
        technicalMessage: technicalMessage ?? 'HTTP $statusCode',
        backendMessage: backendMessage,
        statusCode: statusCode,
      );
    }

    if (statusCode >= 500) {
      return AppNetworkException(
        type: AppNetworkErrorType.serverUnavailable,
        technicalMessage: technicalMessage ?? 'HTTP $statusCode',
        backendMessage: backendMessage,
        statusCode: statusCode,
      );
    }

    return AppNetworkException(
      type: AppNetworkErrorType.business,
      technicalMessage: technicalMessage ?? 'HTTP $statusCode',
      backendMessage: backendMessage,
      statusCode: statusCode,
    );
  }

  @override
  String toString() {
    return 'AppNetworkException(type: $type, statusCode: $statusCode, technicalMessage: $technicalMessage, backendMessage: $backendMessage)';
  }
}

import 'package:flutter/material.dart';

/// Configuración centralizada de la aplicación
/// 
/// CONFIGURACIÓN DEL SERVIDOR:
/// Para cambiar la URL del servidor, usa la variable de entorno API_BASE_URL:
/// 
/// ```bash
/// # Desarrollo local (dispositivo físico)
/// flutter run --dart-define=API_BASE_URL=http://192.168.18.68/viax/backend
/// 
/// # Emulador Android
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2/viax/backend
/// 
/// # Producción
/// flutter run --dart-define=API_BASE_URL=https://viax-backend-production.up.railway.app
/// ```
class AppConfig {
  // Permite recordar el host que ya funcionó para evitar probar todos cada vez
  static String? _cachedWorkingBaseUrl;

  // Variable de entorno para la URL del servidor
  // Configura esto al ejecutar: flutter run --dart-define=API_BASE_URL=http://tu-servidor.com
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.18.68/viax/backend', // Default para desarrollo
  );

  // Key global para manejo de SnackBars sin contexto
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Ambiente actual (detectado automáticamente basado en la URL)
  static Environment get environment {
    if (_envBaseUrl.contains('localhost') || 
        _envBaseUrl.contains('10.0.2.2') || 
        _envBaseUrl.contains('192.168.')) {
      return Environment.development;
    } else if (_envBaseUrl.contains('staging')) {
      return Environment.staging;
    }
    return Environment.production;
  }

  // URL base del servidor - LEE DE LA VARIABLE DE ENTORNO
  static String get baseUrl {
    // Si ya detectamos un host que responde, úsalo directo
    if (_cachedWorkingBaseUrl != null) {
      return _cachedWorkingBaseUrl!;
    }
    return _envBaseUrl;
  }

  /// Lista de candidatos para entorno local. El primero que responda se usa y se cachea.
  static List<String> get baseUrlCandidates {
    // Si es producción o staging, solo usar esa URL
    if (!_envBaseUrl.contains('192.168.') && !_envBaseUrl.contains('10.0.2.2') && !_envBaseUrl.contains('localhost')) {
      return [_envBaseUrl];
    }

    // Para desarrollo, probar varios candidatos
    const candidates = [
      'http://192.168.18.68/viax/backend',
      'http://10.0.2.2/viax/backend',
      'http://127.0.0.1/viax/backend',
      'http://localhost/viax/backend',
    ];

    // Poner el configurado primero
    if (!candidates.contains(_envBaseUrl)) {
      return [_envBaseUrl, ...candidates];
    }

    if (_cachedWorkingBaseUrl != null && candidates.contains(_cachedWorkingBaseUrl!)) {
      return [
        _cachedWorkingBaseUrl!,
        ...candidates.where((c) => c != _cachedWorkingBaseUrl!),
      ];
    }

    // Mover la URL configurada al principio
    return [
      _envBaseUrl,
      ...candidates.where((c) => c != _envBaseUrl),
    ];
  }

  /// Guarda el host que respondió exitosamente para evitar timeouts repetidos
  static void rememberWorkingBaseUrl(String url) {
    _cachedWorkingBaseUrl = url;
  }

  // ============================================
  // MICROSERVICIOS
  // ============================================
  // Cada servicio tiene su propia URL modular
  // En producciÃ³n con servidores separados, cambiar a:
  //   - authServiceUrl: 'https://auth.viax.com/v1'
  //   - conductorServiceUrl: 'https://conductors.viax.com/v1'
  //   - adminServiceUrl: 'https://admin.viax.com/v1'
  
  /// Microservicio de AutenticaciÃ³n y Usuarios
  /// Endpoints: login, register, profile, email_service, etc.
  static String get authServiceUrl => '$baseUrl/auth';
  
  /// Microservicio de Conductores
  /// Endpoints: profile, license, vehicle, trips, earnings, etc.
  static String get conductorServiceUrl => '$baseUrl/conductor';
  
  /// Microservicio de AdministraciÃ³n
  /// Endpoints: dashboard, user_management, audit_logs, etc.
  static String get adminServiceUrl => '$baseUrl/admin';
  
  /// Microservicio de Viajes (futuro)
  static String get tripServiceUrl => '$baseUrl/viajes';
  
  /// Microservicio de Mapas (futuro)
  static String get mapServiceUrl => '$baseUrl/map';
  
  // Alias para compatibilidad con cÃ³digo legacy
  @Deprecated('Usar authServiceUrl en su lugar')
  static String get userServiceUrl => authServiceUrl;

  // ConfiguraciÃ³n de red
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ConfiguraciÃ³n de cachÃ©
  static const Duration cacheExpiration = Duration(hours: 1);
  static const int maxCacheSize = 50 * 1024 * 1024; // 50MB

  // Feature flags (para habilitar/deshabilitar features)
  static const bool enableOfflineMode = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;

  // ConfiguraciÃ³n de mapas
  static const String mapboxAccessToken = 'YOUR_MAPBOX_TOKEN'; // Desde env
  static const double defaultLatitude = -34.603722;
  static const double defaultLongitude = -58.381592;

  // VersiÃ³n de la app
  static const String appVersion = '1.0.0';
  static const String apiVersion = 'v1';
}

/// EnumeraciÃ³n de ambientes
enum Environment {
  development,
  staging,
  production,
}

/// ConfiguraciÃ³n por feature (para microservicios)
/// 
/// Permite configurar cada mÃ³dulo/servicio independientemente.
/// Preparado para migraciÃ³n a arquitectura de microservicios.
class FeatureConfig {
  // ConfiguraciÃ³n del Microservicio de Usuarios
  static const userServiceConfig = {
    'endpoint': '/auth',
    'version': 'v1',
    'timeout': Duration(seconds: 15),
    'retryAttempts': 3,
    'enableCache': false,
  };

  // ConfiguraciÃ³n del mÃ³dulo Conductor
  static const conductorConfig = {
    'endpoint': '/conductor',
    'version': 'v1',
    'timeout': Duration(seconds: 15),
    'retryAttempts': 3,
  };

  // ConfiguraciÃ³n del mÃ³dulo Auth (alias de userService para retrocompatibilidad)
  static const authConfig = {
    'endpoint': '/auth',
    'version': 'v1',
    'timeout': Duration(seconds: 10),
    'tokenExpiration': Duration(hours: 24),
  };

  // ConfiguraciÃ³n del mÃ³dulo Map
  static const mapConfig = {
    'endpoint': '/map',
    'version': 'v1',
    'timeout': Duration(seconds: 20),
    'cacheEnabled': true,
  };
}

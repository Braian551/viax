import 'package:flutter/material.dart';

/// ConfiguraciÃ³n centralizada de la aplicaciÃ³n
/// 
/// Contiene constantes y configuraciones que pueden variar
/// segÃºn el entorno (dev, staging, production).
/// 
/// MIGRACIÃ“N A MICROSERVICIOS:
/// - Estas URLs cambiarÃ­an a endpoints de diferentes servicios
/// - Usa variables de entorno para diferentes ambientes
/// - Considera usar un API Gateway que enrute a los servicios
/// 
/// EJEMPLO CONFIGURACIÃ“N MICROSERVICIOS:
/// ```dart
/// // Desarrollo local
/// static const apiGateway = 'http://localhost:8080';
/// static const conductorServiceUrl = '$apiGateway/conductor-service/v1';
/// static const authServiceUrl = '$apiGateway/auth-service/v1';
/// static const paymentServiceUrl = '$apiGateway/payment-service/v1';
/// 
/// // ProducciÃ³n
/// static const apiGateway = 'https://api.viax.com';
/// static const conductorServiceUrl = '$apiGateway/conductor/v1';
/// ```
class AppConfig {
  // Permite recordar el host que ya funcionó para evitar probar todos cada vez
  static String? _cachedWorkingBaseUrl;

  // Override opcional por variable de entorno en tiempo de compilación
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Key global para manejo de SnackBars sin contexto
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Ambiente actual - CAMBIAR AQUÃ PARA ALTERNAR ENTRE LOCAL Y PRODUCCIÃ“N
  static const Environment environment = Environment.development;

  // URLs base segÃºn ambiente
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    // Si ya detectamos un host que responde, úsalo directo
    if (_cachedWorkingBaseUrl != null) {
      return _cachedWorkingBaseUrl!;
    }

    switch (environment) {
  case Environment.development:
        // DESARROLLO LOCAL CON LARAGON
        // Para navegador web o depuraciÃ³n desde VS Code: localhost
        // Para emulador Android: 10.0.2.2 (IMPORTANTE: usar esta para emulador)
        // Para dispositivo fÃ­sico: usar IP de tu mÃ¡quina (ej: 192.168.1.X)
        
        // DISPOSITIVO FÍSICO - usa tu IP local:
        // return 'http://192.168.18.68/viax/backend';
        
        // EMULADOR ANDROID - descomentar esta línea:
        return 'http://10.0.2.2/viax/backend';
        
      case Environment.staging:
        return 'https://staging-api.viax.com';
      case Environment.production:
        // Railway backend URL - PRODUCCIÃ“N
        return 'https://viax-backend-production.up.railway.app';
    }
  }

  /// Lista de candidatos para entorno local. El primero que responda se usa y se cachea.
  static List<String> get baseUrlCandidates {
    if (_envBaseUrl.isNotEmpty) {
      return [_envBaseUrl];
    }

    switch (environment) {
      case Environment.development:
        const candidates = [
          // IP LAN de la máquina host (para dispositivo físico)
          'http://192.168.18.68/viax/backend',
          // Emulador Android (10.0.2.2 apunta a la máquina host)
          'http://10.0.2.2/viax/backend',
          // Loopback común para desktop
          'http://127.0.0.1/viax/backend',
          'http://localhost/viax/backend',
        ];

        if (_cachedWorkingBaseUrl != null && candidates.contains(_cachedWorkingBaseUrl!)) {
          return [
            _cachedWorkingBaseUrl!,
            ...candidates.where((c) => c != _cachedWorkingBaseUrl!),
          ];
        }

        return candidates;

      case Environment.staging:
        return ['https://staging-api.viax.com'];

      case Environment.production:
        return ['https://viax-backend-production.up.railway.app'];
    }
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

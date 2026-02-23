# 🚀 Guía Rápida: Nuevas Rutas de Microservicios

## 📌 Cambios Importantes en URLs

### ⚠️ Archivos Movidos

#### Email Service
```diff
- ❌ http://10.0.2.2/viax/backend/email_service.php
+ ✅ http://10.0.2.2/viax/backend/auth/email_service.php
```

#### Verify Code
```diff
- ❌ http://10.0.2.2/viax/backend/verify_code.php
+ ✅ http://10.0.2.2/viax/backend/auth/verify_code.php
```

---

## 🎯 Cómo Usar las Rutas Correctamente

### ✅ FORMA CORRECTA: Usar AppConfig

```dart
import 'package:ping_go/src/core/config/app_config.dart';

// Email service
final emailUrl = '${AppConfig.authServiceUrl}/email_service.php';
// Resultado: http://10.0.2.2/viax/backend/auth/email_service.php

// Verify code
final verifyUrl = '${AppConfig.authServiceUrl}/verify_code.php';
// Resultado: http://10.0.2.2/viax/backend/auth/verify_code.php

// Cualquier endpoint de auth
final loginUrl = '${AppConfig.authServiceUrl}/login.php';
final registerUrl = '${AppConfig.authServiceUrl}/register.php';
```

### ❌ FORMA INCORRECTA: URLs Hardcodeadas

```dart
// ❌ NO HACER ESTO
final url = 'http://10.0.2.2/viax/backend/email_service.php';

// ❌ NO HACER ESTO
final url = 'http://10.0.2.2/viax/backend/auth/login.php';
```

---

## 📋 Tabla de Referencia Rápida

### Microservicio: AUTH (`/auth`)

| Endpoint | URL Completa | Uso |
|----------|-------------|-----|
| `login.php` | `${AppConfig.authServiceUrl}/login.php` | Iniciar sesión |
| `register.php` | `${AppConfig.authServiceUrl}/register.php` | Registrar usuario |
| `profile.php` | `${AppConfig.authServiceUrl}/profile.php` | Obtener perfil |
| `profile_update.php` | `${AppConfig.authServiceUrl}/profile_update.php` | Actualizar perfil |
| `check_user.php` | `${AppConfig.authServiceUrl}/check_user.php` | Verificar usuario |
| `email_service.php` | `${AppConfig.authServiceUrl}/email_service.php` | ✅ **Movido aquí** |
| `verify_code.php` | `${AppConfig.authServiceUrl}/verify_code.php` | ✅ **Movido aquí** |

### Microservicio: CONDUCTOR (`/conductor`)

| Endpoint | URL Completa | Uso |
|----------|-------------|-----|
| `get_profile.php` | `${AppConfig.conductorServiceUrl}/get_profile.php` | Perfil conductor |
| `update_profile.php` | `${AppConfig.conductorServiceUrl}/update_profile.php` | Actualizar perfil |
| `update_license.php` | `${AppConfig.conductorServiceUrl}/update_license.php` | Actualizar licencia |
| `update_vehicle.php` | `${AppConfig.conductorServiceUrl}/update_vehicle.php` | Actualizar vehículo |
| `get_estadisticas.php` | `${AppConfig.conductorServiceUrl}/get_estadisticas.php` | Estadísticas |
| `get_ganancias.php` | `${AppConfig.conductorServiceUrl}/get_ganancias.php` | Ganancias |
| `get_historial.php` | `${AppConfig.conductorServiceUrl}/get_historial.php` | Historial viajes |
| `actualizar_disponibilidad.php` | `${AppConfig.conductorServiceUrl}/actualizar_disponibilidad.php` | Disponibilidad |
| `actualizar_ubicacion.php` | `${AppConfig.conductorServiceUrl}/actualizar_ubicacion.php` | Ubicación GPS |

### Microservicio: ADMIN (`/admin`)

| Endpoint | URL Completa | Uso |
|----------|-------------|-----|
| `dashboard_stats.php` | `${AppConfig.adminServiceUrl}/dashboard_stats.php` | Estadísticas dashboard |
| `user_management.php` | `${AppConfig.adminServiceUrl}/user_management.php` | Gestión usuarios |
| `audit_logs.php` | `${AppConfig.adminServiceUrl}/audit_logs.php` | Logs de auditoría |
| `app_config.php` | `${AppConfig.adminServiceUrl}/app_config.php` | Configuración app |

---

## 🔧 Migración de Código Existente

### Ejemplo 1: Email Service

```dart
// ❌ Antes (INCORRECTO)
class EmailService {
  static const String apiUrl = 'http://10.0.2.2/viax/backend/email_service.php';
}

// ✅ Después (CORRECTO)
import '../../core/config/app_config.dart';

class EmailService {
  static String get apiUrl => '${AppConfig.authServiceUrl}/email_service.php';
}
```

### Ejemplo 2: User Service

```dart
// ❌ Antes (INCORRECTO)
final response = await http.post(
  Uri.parse('http://10.0.2.2/viax/backend/auth/register.php'),
  body: jsonEncode(data),
);

// ✅ Después (CORRECTO)
final response = await http.post(
  Uri.parse('${AppConfig.authServiceUrl}/register.php'),
  body: jsonEncode(data),
);
```

### Ejemplo 3: Conductor Service

```dart
// ❌ Antes (INCORRECTO)
class ConductorService {
  static const String baseUrl = 'http://10.0.2.2/viax/backend/conductor';
}

// ✅ Después (CORRECTO)
import '../../../core/config/app_config.dart';

class ConductorService {
  static String get baseUrl => AppConfig.conductorServiceUrl;
}
```

---

## 🌍 Cambio de Ambiente

### Desarrollo → Producción

Solo necesitas cambiar **1 línea** en `AppConfig`:

```dart
// lib/src/core/config/app_config.dart

class AppConfig {
  // Cambiar esta línea
  static const Environment environment = Environment.production;
  
  // El resto se ajusta automáticamente
  static String get baseUrl {
    switch (environment) {
      case Environment.development:
        return 'http://10.0.2.2/viax/backend';
      case Environment.staging:
        return 'https://staging-api.Viax.com';
      case Environment.production:
        return 'https://api.Viax.com/backend';
    }
  }
  
  // Automático para todos los microservicios
  static String get authServiceUrl => '$baseUrl/auth';
  static String get conductorServiceUrl => '$baseUrl/conductor';
  static String get adminServiceUrl => '$baseUrl/admin';
}
```

---

## 🧪 Testing de URLs

### Verificar en Terminal

```dart
void main() {
  print('Auth Service: ${AppConfig.authServiceUrl}');
  print('Conductor Service: ${AppConfig.conductorServiceUrl}');
  print('Admin Service: ${AppConfig.adminServiceUrl}');
  
  // Verificar endpoint específico
  print('Email Service: ${AppConfig.authServiceUrl}/email_service.php');
}
```

### Test Unitario

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ping_go/src/core/config/app_config.dart';

void main() {
  test('Email service URL debe estar en auth/', () {
    final emailUrl = '${AppConfig.authServiceUrl}/email_service.php';
    
    expect(emailUrl, contains('/auth/'));
    expect(emailUrl, contains('email_service.php'));
    expect(emailUrl, isNot(contains('/backend/email_service.php')));
  });
  
  test('Verify code URL debe estar en auth/', () {
    final verifyUrl = '${AppConfig.authServiceUrl}/verify_code.php';
    
    expect(verifyUrl, contains('/auth/'));
    expect(verifyUrl, contains('verify_code.php'));
  });
}
```

---

## 🔍 Búsqueda de URLs Hardcodeadas

### Comando PowerShell

```powershell
# Buscar URLs hardcodeadas en el proyecto
cd c:\Flutter\ping_go
Select-String -Path "lib\**\*.dart" -Pattern "http://10.0.2.2/viax/backend" -CaseSensitive

# Buscar específicamente email_service
Select-String -Path "lib\**\*.dart" -Pattern "email_service\.php" -CaseSensitive

# Buscar verify_code
Select-String -Path "lib\**\*.dart" -Pattern "verify_code\.php" -CaseSensitive
```

### VS Code Search

1. Presiona `Ctrl + Shift + F`
2. Busca: `http://10.0.2.2/viax/backend`
3. Reemplaza con: `${AppConfig.baseUrl}`
4. O mejor: usa el getter específico del microservicio

---

## 📦 Archivos Actualizados

### ✅ Ya Actualizados
- `user_remote_datasource_impl.dart` → Usa `AppConfig.authServiceUrl`
- `conductor_remote_datasource_impl.dart` → Usa `AppConfig.conductorServiceUrl`
- `conductor_service.dart` → Usa `AppConfig.conductorServiceUrl`
- `conductor_profile_service.dart` → Usa `AppConfig.conductorServiceUrl`
- `conductor_earnings_service.dart` → Usa `AppConfig.baseUrl`
- `conductor_trips_service.dart` → Usa `AppConfig.baseUrl`
- `email_service.dart` → Usa `AppConfig.baseUrl`
- `admin_service.dart` → Usa `AppConfig.adminServiceUrl`

### ⚠️ Verificar Si Usas
- Cualquier archivo que llame a `email_service.php` o `verify_code.php`
- Servicios custom que hayas creado
- Tests que usen URLs directas

---

## 🎯 Quick Commands

### Verificar estructura backend
```powershell
cd c:\Flutter\ping_go\Viax\backend
Get-ChildItem -Recurse -Filter "*.php" | Select-Object FullName
```

### Verificar imports de AppConfig
```powershell
cd c:\Flutter\ping_go
Select-String -Path "lib\**\*.dart" -Pattern "import.*app_config" -CaseSensitive
```

---

## 📞 Soporte

Si encuentras problemas:
1. Verifica que uses `AppConfig` en lugar de URLs hardcodeadas
2. Confirma que los archivos PHP estén en las carpetas correctas
3. Revisa la documentación completa: [MICROSERVICES_CLEANUP.md](./MICROSERVICES_CLEANUP.md)

---

**Última actualización**: Octubre 2025  
**Versión**: 1.0.0

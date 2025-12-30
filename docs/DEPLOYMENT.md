# 🚀 Despliegue Viax - Guía Completa

## 📋 **Estado Actual del Despliegue**

### ✅ **Servicios Activos**

| Servicio | URL | Estado | Tecnología |
|----------|-----|--------|------------|
| **Backend API** | https://viax-backend-production.up.railway.app | ✅ Activo | PHP 8.3 + MySQL |
| **Base de Datos** | sql10.freesqldatabase.com | ✅ Activo | MySQL 8.0 |
| **Frontend** | - | ✅ Listo | Flutter (Build manual) |

## 🖥️ **Backend (Railway)**

### 📍 **Información del Servicio**
- **Nombre**: viax-backend-production
- **URL**: https://viax-backend-production.up.railway.app
- **Framework**: PHP 8.3 puro (sin framework)
- **Base de datos**: MySQL externa (freesqldatabase.com)
- **Email**: PHPMailer con Gmail SMTP

### 🔧 **Configuración Técnica**
```php
// Configuración de base de datos
define('DB_HOST', 'sql10.freesqldatabase.com');
define('DB_NAME', 'sql10740070');
define('DB_USER', 'sql10740070');
define('DB_PASS', '********');

// URLs del backend
define('BASE_URL', 'https://viax-backend-production.up.railway.app');
```

### 📁 **Estructura del Backend**
```
viax-backend (Railway)
├── auth/
│   ├── login.php              # Inicio de sesión
│   ├── register.php           # Registro de usuarios
│   ├── email_service.php      # Verificación por email
│   ├── check_user.php         # Verificación de usuario
│   └── verify_code.php        # Verificación de códigos
├── user/
│   ├── profile.php            # Perfil de usuario
│   └── update_profile.php     # Actualización de perfil
├── conductor/
│   ├── register.php           # Registro de conductor
│   ├── documents.php          # Gestión de documentos
│   └── profile.php            # Perfil de conductor
├── admin/
│   ├── dashboard_stats.php    # Estadísticas del dashboard
│   ├── user_management.php    # Gestión de usuarios
│   └── trip_management.php    # Gestión de viajes
├── config/
│   └── database.php           # Configuración de BD
├── vendor/                    # Dependencias (Composer)
└── index.php                  # Archivo principal
```

### 🔗 **Endpoints Principales**

#### 👤 **Autenticación**
```
POST /auth/register.php         # Registro de usuario
POST /auth/login.php            # Inicio de sesión
POST /auth/email_service.php    # Envío de código de verificación
POST /auth/check_user.php       # Verificación de usuario existente
POST /auth/verify_code.php      # Verificación de código
```

#### 👨‍💼 **Administración**
```
GET  /admin/dashboard_stats.php?admin_id=1    # Estadísticas del dashboard
GET  /admin/user_management.php?page=1        # Gestión de usuarios
```

#### 🔍 **Sistema**
```
GET  /verify_system_json.php   # Verificación del sistema
```

## 🗄️ **Base de Datos (MySQL)**

### 📍 **Información de Conexión**
- **Host**: sql10.freesqldatabase.com
- **Puerto**: 3306
- **Base de datos**: sql10740070
- **Usuario**: sql10740070
- **Tipo**: MySQL 8.0

### 📊 **Tablas Principales**
```sql
-- Usuarios del sistema
usuarios (
    id, uuid, nombre, apellido, email, telefono,
    tipo_usuario, foto_perfil, es_verificado, es_activo,
    fecha_registro, fecha_actualizacion
)

-- Conductores
conductores (
    id, usuario_id, numero_licencia, fecha_expiracion_licencia,
    marca_vehiculo, modelo_vehiculo, placa_vehiculo,
    foto_licencia, foto_vehiculo, es_aprobado
)

-- Viajes/Solicitudes
solicitudes_viaje (
    id, usuario_id, conductor_id, origen_lat, origen_lng,
    destino_lat, destino_lng, estado, fecha_creacion
)

-- Actividad del sistema
actividad_sistema (
    id, usuario_id, accion, descripcion, fecha_creacion
)
```

### 🛠️ **Gestión de Base de Datos**
- **Acceso**: phpMyAdmin o MySQL Workbench
- **Backup**: Automático en freesqldatabase.com
- **Migraciones**: Scripts SQL manuales

## 📧 **Sistema de Email**

### 📍 **Configuración**
- **Servicio**: Gmail SMTP
- **Librería**: PHPMailer
- **Puerto**: 587 (STARTTLS)
- **Seguridad**: Encriptación TLS

### 🔧 **Configuración Técnica**
```php
// Configuración SMTP (email_service.php)
$mail->isSMTP();
$mail->Host = 'smtp.gmail.com';
$mail->SMTPAuth = true;
$mail->Username = 'braianoquendurango@gmail.com';
$mail->Password = 'app_password'; // Contraseña de aplicación
$mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
$mail->Port = 587;
```

### 📨 **Funcionalidades**
- ✅ Envío de códigos de verificación (6 dígitos)
- ✅ Emails HTML con diseño profesional
- ✅ Validación de direcciones de email
- ✅ Logs de envío en Railway

## 📱 **Frontend (Flutter)**

### 📦 **Build de Producción**
```bash
# APK para instalación directa
flutter build apk --release

# AAB para Google Play Store
flutter build appbundle --release

# Instalación en dispositivo
flutter install
```

### 🔧 **Configuración de APIs**
```dart
// lib/src/core/constants/app_constants.dart
const String baseUrl = 'https://viax-backend-production.up.railway.app';

// lib/src/core/config/env_config.dart
const String mapboxAccessToken = 'tu_token_mapbox';
const String tomtomApiKey = 'tu_api_key_tomtom';
```

## 🚀 **Proceso de Despliegue**

### 🔄 **Backend (Automático)**
1. **Push a rama main** en `viax-backend`
2. **Railway detecta cambios** automáticamente
3. **Build con Nixpacks** (PHP + Composer)
4. **Despliegue automático** en minutos
5. **URL actualizada** automáticamente

### 📱 **Frontend (Manual)**
1. **Build local**: `flutter build apk --release`
2. **Pruebas**: Instalar en dispositivo/emulador
3. **Distribución**: Compartir APK o subir a Play Store
4. **Actualización**: Nueva versión del código

## 📊 **Monitoreo y Logs**

### 📋 **Railway Dashboard**
- **Logs en tiempo real** del backend
- **Métricas de uso** (CPU, RAM, requests)
- **Estado del servicio** (uptime)
- **Variables de entorno**

### 🔍 **Base de Datos**
- **Conexiones activas** en freesqldatabase.com
- **Espacio usado** y límites
- **Queries lentas** (logs)
- **Backup automático**

### 📱 **App Flutter**
- **Logs de desarrollo**: `flutter logs`
- **Errores de red**: Charles Proxy o similar
- **Crash reports**: Firebase Crashlytics (si se configura)

## 🆘 **Solución de Problemas**

### 🔧 **Backend no responde**
```bash
# Verificar estado
curl https://viax-backend-production.up.railway.app/verify_system_json.php

# Revisar logs en Railway dashboard
# Verificar conexión a base de datos
```

### 📧 **Email no llega**
- Verificar configuración SMTP
- Revisar logs de PHPMailer
- Confirmar contraseña de aplicación de Gmail
- Verificar spam/junk

### 📱 **App no conecta al backend**
- Verificar URLs en `app_constants.dart`
- Confirmar conectividad a internet
- Revisar logs de Flutter: `flutter logs`

## 🔄 **Actualizaciones**

### 🚀 **Backend**
```bash
cd viax-backend
git add .
git commit -m "Nueva funcionalidad"
git push origin main
# Railway despliega automáticamente
```

### 📱 **Frontend**
```bash
cd viax
flutter build apk --release
# Distribuir APK actualizado
```

## 📞 **Soporte**

- **Railway**: Dashboard en railway.app
- **Base de datos**: Panel de freesqldatabase.com
- **Flutter**: `flutter doctor` para diagnóstico
- **Documentación**: Ver carpeta `docs/`

---

**📅 Última actualización**: Octubre 2025  
**🎯 Estado**: Sistema completamente funcional en producción
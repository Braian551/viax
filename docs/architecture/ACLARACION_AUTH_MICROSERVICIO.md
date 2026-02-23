# 🔍 Aclaración: Auth SÍ es un Microservicio

## ✅ Estructura Actual de Microservicios

```
backend/
├── auth/          ✅ MICROSERVICIO #1 - Autenticación y Usuarios
├── conductor/     ✅ MICROSERVICIO #2 - Conductores y Viajes
└── admin/         ✅ MICROSERVICIO #3 - Administración
```

**Todos son microservicios** 🎯

---

## 📝 Nomenclatura Correcta

### En Backend (PHP)
```
/auth       → Microservicio de Autenticación
/conductor  → Microservicio de Conductores
/admin      → Microservicio de Admin
```

### En Frontend (Flutter)
```dart
AppConfig.authServiceUrl       → Microservicio de Auth
AppConfig.conductorServiceUrl  → Microservicio de Conductores
AppConfig.adminServiceUrl      → Microservicio de Admin
```

---

## ⚠️ Aclaración de Nombres

**Antes teníamos confusión**:
- `userServiceUrl` → ¿Es de usuarios o de auth?
- `authServiceUrl` → ¿Es diferente a userServiceUrl?

**Ahora está claro**:
```dart
// ✅ NOMBRE OFICIAL
static String get authServiceUrl => '$baseUrl/auth';

// ⚠️ Deprecated (solo para compatibilidad)
@Deprecated('Usar authServiceUrl en su lugar')
static String get userServiceUrl => authServiceUrl;
```

---

## 🎯 ¿Por Qué "Auth" y No "User"?

### Auth Service incluye:
- ✅ Autenticación (login/register)
- ✅ Gestión de usuarios (profile)
- ✅ Verificación por email
- ✅ Manejo de sesiones
- ✅ Direcciones de usuarios

**Es más que solo "usuarios"**, es el servicio de **autenticación completo**.

---

## 📊 Comparación de Nombres

| Concepto | Backend | Flutter | Descripción |
|----------|---------|---------|-------------|
| Autenticación | `/auth` | `authServiceUrl` | Login, register, profile, email |
| Conductores | `/conductor` | `conductorServiceUrl` | Perfil, licencia, vehículo, viajes |
| Administración | `/admin` | `adminServiceUrl` | Dashboard, gestión, logs |

---

## 🔄 Migración de Nombres

Si tienes código que usa `userServiceUrl`, **actualízalo**:

```dart
// ❌ Antiguo (deprecated)
final url = '${AppConfig.userServiceUrl}/login.php';

// ✅ Nuevo (oficial)
final url = '${AppConfig.authServiceUrl}/login.php';
```

---

## 🏗️ Arquitectura Actual

```
┌─────────────────────────────────────┐
│         Flutter App                  │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         AppConfig                    │
│  • authServiceUrl                    │
│  • conductorServiceUrl               │
│  • adminServiceUrl                   │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│    Backend Microservices             │
│                                      │
│  ┌───────────┐  ┌───────────┐      │
│  │   Auth    │  │ Conductor │      │
│  │ Service   │  │  Service  │  ... │
│  └───────────┘  └───────────┘      │
└─────────────────────────────────────┘
```

**Todos son microservicios**, solo están en un mismo servidor por ahora.

---

## 🚀 Escalamiento Futuro

### Fase Actual: Monolito Modular
```
Single Server (localhost/xampp)
  ├── /auth       (Microservicio #1)
  ├── /conductor  (Microservicio #2)
  └── /admin      (Microservicio #3)
```

### Fase Futura: Servidores Separados
```
API Gateway
  ├── auth.Viax.com       → Auth Service
  ├── conductors.Viax.com → Conductor Service
  └── admin.Viax.com      → Admin Service
```

**Solo cambiar URLs en AppConfig** ✨

---

## ✅ Resumen

1. **Auth SÍ es un microservicio** (siempre lo fue)
2. **El nombre oficial es `authServiceUrl`** (no `userServiceUrl`)
3. **Todos están en `/backend/` por ahora** (mismo servidor)
4. **Fácil de separar en el futuro** (solo cambiar AppConfig)

---

**¿Confundido?** Piensa así:
- `auth/` = Microservicio completo ✅
- `conductor/` = Microservicio completo ✅  
- `admin/` = Microservicio completo ✅

Solo comparten el mismo servidor y base de datos **por ahora**. Están diseñados para separarse fácilmente.

---

**Última actualización**: Octubre 2025  
**Estado**: ✅ Nomenclatura estandarizada

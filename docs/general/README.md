# Ping Go - Documentación del Proyecto

## 📋 Índice de Documentación

### 🏗️ Arquitectura
- **[README de Arquitectura](../architecture/README.md)** - **LEER PRIMERO** - Visión general de la arquitectura
- **[Clean Architecture](../architecture/CLEAN_ARCHITECTURE.md)** - Guía completa de la arquitectura implementada
- **[Migración a Microservicios](../architecture/MIGRATION_TO_MICROSERVICES.md)** - Plan para escalar el proyecto
- **[Decisiones Arquitectónicas (ADR)](../architecture/ADR.md)** - Registro de decisiones importantes
- **[Resumen de Refactorización](../architecture/REFACTORING_SUMMARY.md)** - Cambios recientes implementados

### 🚗 Módulo Conductor
- [Guía Rápida](../conductor/GUIA_RAPIDA.md)
- [Nuevas Funcionalidades](../conductor/NUEVAS_FUNCIONALIDADES.md)
- [Backend Endpoints](../conductor/BACKEND_ENDPOINTS.md)

### 🗺️ Módulo Mapbox
- [Setup de Mapbox](../mapbox/MAPBOX_SETUP.md)
- [Cheat Sheet](../mapbox/CHEAT_SHEET.md)
- [Estructura](../mapbox/ESTRUCTURA.md)

### 📱 Otros Módulos
- [Onboarding](../onboarding/)
- [Home](../home/)

---

## 🚀 Getting Started

### Requisitos Previos
- Flutter SDK 3.x
- Dart SDK
- Android Studio / Xcode (para emuladores)
- Servidor PHP local (XAMPP/WAMP/MAMP)

### Instalación

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/Braian551/viax.git
   cd viax
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar backend local**
   - Ubicación: `viax/backend/`
   - Importar BD: `basededatos.sql`
   - Configurar PHP en `localhost` o tu servidor local

4. **Configurar constantes**
   - Copiar `lib/src/core/constants/app_constants.example.dart` a `app_constants.dart`
   - Actualizar URLs según tu ambiente

5. **Ejecutar app**
   ```bash
   flutter run
   ```

---

## 🔧 Backend Local - Endpoints

Durante desarrollo, el backend PHP está en `viax/backend/`. Los endpoints principales son:

### Autenticación
- **POST** `/auth/register.php` - Registrar usuario
  ```json
  {
    "email": "test@example.com",
    "password": "pass123",
    "name": "Test",
    "lastName": "User",
    "phone": "3001234567",
    "address": "Calle 123",
    "lat": 4.711,
    "lng": -74.072
  }
  ```

- **GET** `/auth/profile.php?email=foo@bar.com` - Obtener perfil

### Conductor
- **GET** `/conductor/get_profile.php?conductor_id=X` - Obtener perfil completo
- **POST** `/conductor/update_profile.php` - Actualizar perfil
- **POST** `/conductor/update_license.php` - Actualizar licencia
- **POST** `/conductor/update_vehicle.php` - Actualizar vehículo
- **POST** `/conductor/submit_for_approval.php` - Enviar para aprobación

### Configuración para Emulador Android
Usar `http://10.0.2.2/viax/backend/` como base URL.

### Prueba rápida con curl
```bash
curl -X POST http://localhost/viax/backend/auth/register.php \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"pass123","name":"Test","lastName":"User","phone":"3001234567"}'
```

---

## 🏗️ Arquitectura del Proyecto (Resumen)

El proyecto implementa **Clean Architecture** con tres capas:

```
┌───────────────────────────────────────┐
│    Presentation (UI + Estado)        │  ← Flutter widgets, providers
├───────────────────────────────────────┤
│    Domain (Lógica de Negocio)        │  ← Entidades, use cases (PURO)
├───────────────────────────────────────┤
│    Data (Persistencia)                │  ← APIs, BD, cache
└───────────────────────────────────────┘
```

**Ventajas**:
- ✅ Código mantenible y testeable
- ✅ Separación clara de responsabilidades
- ✅ Preparado para escalar a microservicios
- ✅ Independiente de frameworks

**Detalles completos**: Ver [Clean Architecture](../architecture/CLEAN_ARCHITECTURE.md)

---

## 📦 Estructura del Proyecto

```
lib/
├── main.dart
├── src/
│   ├── core/                    # Código compartido
│   │   ├── config/              # Configuración
│   │   ├── di/                  # Inyección de dependencias
│   │   ├── error/               # Manejo de errores
│   │   └── ...
│   ├── features/                # Módulos por funcionalidad
│   │   ├── conductor/           # Feature: Conductor
│   │   │   ├── domain/          # Lógica de negocio
│   │   │   ├── data/            # Implementación
│   │   │   └── presentation/    # UI
│   │   ├── auth/
│   │   ├── map/
│   │   └── ...
│   ├── routes/                  # Navegación
│   └── widgets/                 # Widgets globales
```

---

## 🧪 Testing

### Ejecutar tests
```bash
# Todos los tests
flutter test

# Tests específicos
flutter test test/features/conductor/

# Con coverage
flutter test --coverage
```

### Estrategia de testing
- **Unit tests**: Domain layer (lógica de negocio)
- **Integration tests**: Data layer (repositories)
- **Widget tests**: Presentation layer (UI)
- **E2E tests**: Flujos completos

---

## 🎨 Convenciones de Código

### Estructura de Features
```
features/{feature_name}/
├── domain/
│   ├── entities/          # Objetos de negocio inmutables
│   ├── repositories/      # Contratos abstractos
│   └── usecases/          # Reglas de negocio
├── data/
│   ├── datasources/       # APIs, BD
│   ├── models/            # DTOs con serialización
│   └── repositories/      # Implementaciones
└── presentation/
    ├── providers/         # Gestión de estado
    ├── screens/           # Pantallas
    └── widgets/           # Componentes
```

### Nombrado
- **Clases**: PascalCase (`ConductorProfile`)
- **Archivos**: snake_case (`conductor_profile.dart`)
- **Variables**: camelCase (`conductorId`)
- **Constantes**: SCREAMING_SNAKE_CASE (`API_BASE_URL`)

---

## 🤝 Contribuir

### Workflow
1. Crear rama desde `main`: `git checkout -b feature/nueva-feature`
2. Implementar cambios siguiendo Clean Architecture
3. Escribir tests
4. Commit con mensajes descriptivos
5. Push y crear Pull Request
6. Code review
7. Merge a `main`

### Commits
Seguir [Conventional Commits](https://www.conventionalcommits.org/):
```
feat: agregar endpoint de pagos
fix: corregir error en cálculo de distancia
docs: actualizar README con nuevas rutas
refactor: migrar conductor a Clean Architecture
test: agregar tests para use cases
```

---

## 📚 Recursos Útiles

### Flutter
- [Documentación oficial](https://docs.flutter.dev/)
- [Cookbook](https://docs.flutter.dev/cookbook)
- [Widget catalog](https://docs.flutter.dev/development/ui/widgets)

### Arquitectura
- [Clean Architecture - Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Clean Architecture Tutorial](https://github.com/ResoCoder/flutter-tdd-clean-architecture-course)

### Estado del Proyecto
- **Versión actual**: 1.0.0 (Demo/MVP)
- **Estado**: En desarrollo activo
- **Target**: Pueblo pequeño (demo)
- **Preparación**: Lista para escalar a microservicios si crece

---

## 📞 Contacto y Soporte

- **GitHub**: [Braian551/viax](https://github.com/Braian551/viax)
- **Documentación**: `docs/`
- **Issues**: GitHub Issues

---

**Última actualización**: Octubre 2025  
**Mantenido por**: Equipo Viax

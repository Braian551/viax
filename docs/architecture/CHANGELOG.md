# CHANGELOG - Refactorización Clean Architecture

## [2026-05-18] - Sesión robusta y arranque seguro

### Flutter App

- El arranque ya no trata cualquier rastro local como sesión iniciada: `UserService` ahora distingue entre sesión `active` y sesión `pending`, y solo permite autoentrada por rol cuando hay identidad completa y estado autenticado válido.
- Los flujos de login, Google Sign-In, reactivación de cuenta, registro y recuperación de teléfono ahora persisten el estado de sesión con intención explícita, evitando que registros parciales o correos aislados disparen navegación directa a home.
- `SplashScreen`, `WelcomeScreen`, `AuthWrapper`, la sincronización de push, la apertura por notificaciones y el WebSocket dejaron de arrancar servicios o navegar por rol con sesiones provisionales o restauradas de forma incompleta.
- La app Android deshabilitó `allowBackup` y `fullBackupContent` en el manifest principal para impedir que `SharedPreferences` restaure sesiones antiguas tras desinstalar e instalar desde Play Store.

## [2026-05-17] - Favoritos y eliminación segura

### Flutter App

- La eliminación de cuenta dejó el segundo `AlertDialog` embebido y ahora navega a un flujo compartido de verificación por correo, reutilizable entre cliente, conductor y empresa desde `AccountDeletionFlow`.
- Se extrajo una vista reutilizable para pantallas introductorias de verificación, usada por cambio de contraseña y por la nueva entrada del flujo de eliminación de cuenta.
- El guardado local de direcciones favoritas ahora actualiza el estado de la UI antes de la recarga remota, evitando dejar la vista stale si la sincronización posterior falla.
- El chip de `Favoritos` en la búsqueda rápida dejó de estirar el contador en altura completa y ahora muestra un badge circular fijo, consistente en tamaños angostos.
- El preview del viaje ahora espera a que el mapa termine de estar listo antes de ajustar la cámara a la ruta y usa padding dinámico, evitando el lienzo en blanco inicial y el zoom excesivamente alejado en trayectos como Terminal del Norte.
- Los mapas raster del flujo de cliente ahora reutilizan un `TileProvider` compartido con caché integrado de `flutter_map`, para reaprovechar tiles entre el mapa inicial y los previews en vez de reconstruir un cliente nuevo en cada ruta.
- El preview del viaje ahora difiere unos milisegundos el montaje del mapa completo y lo activa de inmediato cuando el usuario destapa más mapa, priorizando que la ruta y la cotización aparezcan antes.
- El preview del viaje dejó de mostrar el aviso visual `Preparando mapa...`; durante la carga diferida ahora conserva un fondo neutro para no introducir ruido innecesario al cliente.

### Backend PHP

- Los endpoints de direcciones guardadas (`get`, `save`, `delete`) ahora validan y autocorrigen las columnas `tipo_guardado` y `nombre_guardado` en `ubicaciones_usuario` antes de operar, para que favoritos siga funcionando incluso si la migración llegó incompleta a un entorno.
- El guardado de lugares favoritos ahora deriva `ciudad`, `departamento` y `pais` desde la dirección cuando el buscador no envía esos campos explícitamente, evitando fallos por restricciones `NOT NULL` en producción.

## [2026-05-17] - Ajustes de apariencia y scroll

### Flutter App

- Se eliminó el `overscroll glow` azul de toda la app desde `MaterialApp`, para evitar el tinte azul al arrastrar en perfil, viajes y ajustes.
- Se agregó una pantalla compartida de `Apariencia` con selección explícita de `Claro`, `Oscuro` y `Seguir al dispositivo`.
- La preferencia por defecto permanece en `ThemeMode.system`, y al salir de ese modo se conserva el tema efectivo actual para evitar saltos visuales.
- Los ajustes de cliente y conductor ahora abren la misma sección de apariencia en vez de usar un switch aislado, dejando el comportamiento del tema consistente entre roles.
- La vista de `Apariencia` dejó el mock genérico y ahora usa previews inspiradas en el header, tarjetas y navegación de Viax, corrigiendo además el overflow en pantallas angostas.
- La preview de `Apariencia` ajustó sus bordes claros al estilo de tarjetas usadas en la app y redujo el ancho del selector del navbar mock para alinearlo con el componente real.
- En perfil y viajes embebidos se dejó de extender el body detrás del header compartido, eliminando el bloque oscuro al hacer scroll y manteniendo una separación limpia sin superposiciones artificiales.
- El header compartido dejó de usar el `AppBar` material por defecto y ahora se dibuja como una capa transparente propia, para evitar el bloque azul detrás del saludo en claro sin reintroducir interferencia con el contenido.
- La preview de `Apariencia` recolocó los iconos de viajes y perfil dentro del navbar mock y sustituyó contornos grises/negros por bordes azulados sutiles, en línea con pantallas como `Mis direcciones`.

## [1.0.0] - Octubre 2025

### 🎉 Refactorización Mayor: Implementación de Clean Architecture

#### ✨ Nuevas Características

##### Core Module (Módulo Compartido)
- **Sistema de Manejo de Errores**
  - `core/error/failures.dart`: Errores de dominio (ServerFailure, ConnectionFailure, ValidationFailure, etc.)
  - `core/error/exceptions.dart`: Excepciones técnicas (ServerException, NetworkException, etc.)
  - `core/error/result.dart`: Tipo Result<T> para programación funcional (Success/Error)

- **Configuración Centralizada**
  - `core/config/app_config.dart`: Configuración de URLs, timeouts, feature flags
  - Soporte para múltiples ambientes (development, staging, production)
  - Preparación para URLs de microservicios

- **Inyección de Dependencias**
  - `core/di/service_locator.dart`: Service Locator pattern para gestión de dependencias
  - Configuración centralizada de datasources, repositories y use cases
  - Método factory para crear providers configurados

##### Feature: Conductor (Refactorización Completa)

**Domain Layer (Lógica de Negocio Pura)**
- `domain/entities/conductor_profile.dart`:
  - Entidades inmutables: ConductorProfile, DriverLicense, Vehicle
  - Lógica de negocio: cálculo de completitud, validaciones
  - Sin dependencias de frameworks

- `domain/repositories/conductor_repository.dart`:
  - Contrato abstracto del repositorio
  - Define operaciones sin implementación
  - Usa Result<T> para manejo de errores

- `domain/usecases/`:
  - `get_conductor_profile.dart`: Obtener perfil
  - `update_conductor_profile.dart`: Actualizar perfil
  - `update_driver_license.dart`: Actualizar licencia con validación de vencimiento
  - `update_vehicle.dart`: Actualizar vehículo
  - `submit_profile_for_approval.dart`: Enviar para aprobación (valida completitud)

**Data Layer (Implementación de Persistencia)**
- `data/datasources/conductor_remote_datasource.dart`: Interface del datasource
- `data/datasources/conductor_remote_datasource_impl.dart`:
  - Implementación HTTP con manejo de errores
  - Logging de requests/responses
  - Conversión de respuestas a excepciones tipadas

- `data/models/conductor_profile_model.dart`:
  - DTOs que extienden entidades
  - Serialización JSON (toJson/fromJson)
  - Conversión entre models y entities

- `data/repositories/conductor_repository_impl.dart`:
  - Implementación del contrato del dominio
  - Coordinación de datasources
  - Conversión de excepciones a failures
  - Transformación models → entities

**Presentation Layer (UI Refactorizada)**
- `presentation/providers/conductor_profile_provider_refactored.dart`:
  - Provider usando use cases (sin lógica de negocio)
  - Gestión de estado (loading, error, success)
  - Métodos para todas las operaciones CRUD

#### 📚 Documentación

**Nuevos Documentos**
- `docs/architecture/README.md`: Índice principal de arquitectura
- `docs/architecture/CLEAN_ARCHITECTURE.md`: Guía completa (4000+ palabras)
  - Explicación de capas
  - Diagramas de flujo
  - Ejemplos de código
  - Guías de testing
  - Buenas prácticas

- `docs/architecture/MIGRATION_TO_MICROSERVICES.md`: Plan de migración (5000+ palabras)
  - Cuándo migrar
  - Servicios propuestos (7 servicios)
  - Migración paso a paso (6 fases)
  - Configuración técnica (API Gateway, Message Queue, etc.)
  - Manejo de transacciones distribuidas (Saga Pattern)
  - Monitoreo y observabilidad

- `docs/architecture/ADR.md`: Registro de Decisiones Arquitectónicas
  - 7 ADRs documentando decisiones clave
  - Justificaciones y alternativas consideradas
  - Consecuencias de cada decisión

- `docs/architecture/REFACTORING_SUMMARY.md`: Resumen de cambios
  - Comparación antes/después
  - Lista completa de archivos creados
  - Métricas de calidad mejoradas

**Documentación Actualizada**
- `docs/general/README.md`: Actualizado con índice completo y referencias a arquitectura

#### 🔧 Cambios Técnicos

**Patrones Implementados**
- Clean Architecture (Uncle Bob)
- Repository Pattern
- Use Case Pattern (Single Responsibility)
- Result Type (Functional Error Handling)
- Service Locator (Dependency Injection)
- DTO Pattern (Data Transfer Objects)

**Separación de Responsabilidades**
- Domain: Lógica de negocio pura (0% dependencias externas)
- Data: Implementación de persistencia (HTTP, BD, cache)
- Presentation: UI y gestión de estado

**Mejoras en Testabilidad**
- Domain layer: 100% unit testeable sin mocks
- Data layer: Testeable con mocks de datasources
- Presentation: Testeable con mocks de use cases

#### 🚀 Preparación para Microservicios

**Abstracciones Implementadas**
- Datasources con interfaces intercambiables
- Configuración de URLs centralizada
- Repositorio puede coordinar múltiples servicios
- Documentación completa de migración

**Servicios Propuestos (Futuros)**
1. Auth Service (Puerto 8001)
2. Conductor Service (Puerto 8002)
3. Passenger Service (Puerto 8003)
4. Map Service (Puerto 8004)
5. Payment Service (Puerto 8005)
6. Notification Service (Puerto 8006)
7. Admin Service (Puerto 8007)

#### 📁 Estructura de Archivos

**Archivos Creados (Total: 25+)**
```
lib/src/
├── core/
│   ├── config/app_config.dart
│   ├── di/service_locator.dart
│   └── error/
│       ├── failures.dart
│       ├── exceptions.dart
│       └── result.dart
└── features/conductor/
    ├── domain/
    │   ├── entities/conductor_profile.dart
    │   ├── repositories/conductor_repository.dart
    │   └── usecases/ (5 archivos)
    ├── data/
    │   ├── datasources/ (2 archivos)
    │   ├── models/conductor_profile_model.dart
    │   └── repositories/conductor_repository_impl.dart
    └── presentation/
        └── providers/conductor_profile_provider_refactored.dart

docs/architecture/
├── README.md
├── CLEAN_ARCHITECTURE.md
├── MIGRATION_TO_MICROSERVICES.md
├── ADR.md
├── REFACTORING_SUMMARY.md
└── CHANGELOG.md
```

#### 🎯 Métricas de Calidad

**Antes**
- Acoplamiento: Alto
- Cohesión: Baja
- Testabilidad: Difícil
- Líneas de código: ~500 (conductor module)

**Después**
- Acoplamiento: Bajo (dependencias invertidas)
- Cohesión: Alta (Single Responsibility)
- Testabilidad: Excelente (100% en domain)
- Líneas de código: ~1200 (mejor organizado)
- Documentación: +15,000 palabras

#### 🐛 Correcciones

- Movimiento de imports para evitar errores de compilación
- Corrección de tipos en Result<T>
- Validación de fechas de expiración en licencias

#### 🔄 Cambios No Retrocompatibles

**Provider Refactorizado**
- El nuevo `ConductorProfileProvider` requiere inyección de use cases
- Se recomienda usar `ServiceLocator().createConductorProfileProvider()`
- El provider antiguo aún existe en `providers/conductor_profile_provider.dart`

**Modelos Movidos**
- Modelos originales en `models/` siguen existiendo
- Nuevos modelos en `data/models/` extienden entidades del dominio
- Migración gradual recomendada

#### 📝 Notas de Migración

**Para Desarrolladores**
1. Leer [Clean Architecture](./docs/architecture/CLEAN_ARCHITECTURE.md) (obligatorio)
2. Revisar [ADR](./docs/architecture/ADR.md) para entender decisiones
3. Usar ServiceLocator para DI
4. Seguir estructura domain/data/presentation para nuevas features

**Para Futuras Features**
- Copiar estructura de `features/conductor/`
- Implementar en orden: domain → data → presentation
- Escribir tests para cada capa
- Documentar decisiones en ADR si son significativas

#### 🚧 Trabajo Pendiente

**Corto Plazo**
- [ ] Refactorizar feature `auth/` con Clean Architecture
- [ ] Refactorizar feature `map/` con Clean Architecture
- [ ] Refactorizar feature `admin/` con Clean Architecture
- [ ] Implementar tests unitarios para domain layer
- [ ] Implementar tests de integración para data layer

**Mediano Plazo**
- [ ] Migrar de Provider a Riverpod/BLoC (opcional)
- [ ] Implementar cache local (offline-first)
- [ ] Agregar logging estructurado
- [ ] Configurar CI/CD con tests automáticos

**Largo Plazo**
- [ ] Evaluar migración a microservicios (si escala)
- [ ] Implementar API Gateway
- [ ] Separar bases de datos
- [ ] Configurar observabilidad (Prometheus, Grafana, Jaeger)

#### 🎓 Recursos

**Documentación del Proyecto**
- [README Principal](./docs/architecture/README.md)
- [Clean Architecture](./docs/architecture/CLEAN_ARCHITECTURE.md)
- [Migración a Microservicios](./docs/architecture/MIGRATION_TO_MICROSERVICES.md)
- [ADR](./docs/architecture/ADR.md)

**Referencias Externas**
- Clean Architecture by Uncle Bob
- Flutter Clean Architecture Tutorial (ResoCoder)
- Microservices.io Patterns
- Domain-Driven Design by Martin Fowler

---

## Versiones Anteriores

### [0.x.x] - Pre-refactorización
- Implementación inicial de features
- Estructura básica de Flutter
- Backend PHP monolítico
- Sin arquitectura definida

---

**Fecha de refactorización**: Octubre 2025  
**Versión**: 1.0.0  
**Estado**: ✅ Completado - Feature Conductor refactorizada  
**Próximo paso**: Refactorizar otros features con misma estructura

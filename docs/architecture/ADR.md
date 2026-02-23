# Registro de Decisiones Arquitectónicas (ADR)

## ADR-001: Implementación de Clean Architecture

**Fecha**: Octubre 2025  
**Estado**: Aprobado  
**Autores**: Equipo Ping Go

### Contexto
El proyecto Ping Go es una aplicación de transporte para un pueblo pequeño (demo/MVP). Necesitamos una arquitectura que sea:
- Fácil de mantener y evolucionar
- Testeable
- Preparada para escalar en el futuro si el proyecto crece

### Decisión
Implementar **Clean Architecture** con tres capas claramente separadas:
- **Domain Layer**: Lógica de negocio pura (entidades, use cases, contratos)
- **Data Layer**: Implementación de persistencia (datasources, repositories, models)
- **Presentation Layer**: UI y gestión de estado (providers, screens, widgets)

### Justificación
1. **Separación de responsabilidades**: Cada capa tiene un propósito claro
2. **Independencia de frameworks**: La lógica de negocio no depende de Flutter o APIs específicas
3. **Testabilidad**: Cada capa se puede testear independientemente
4. **Escalabilidad futura**: Si el proyecto crece, podemos migrar a microservicios sin reescribir todo

### Alternativas Consideradas
- **MVC tradicional**: Más simple pero mezcla UI y lógica
- **BLoC pattern puro**: Solo gestión de estado, no arquitectura completa
- **MVVM**: Similar a Clean pero menos estricto en separación

### Consecuencias
**Positivas**:
- ✅ Código más organizado y mantenible
- ✅ Fácil agregar nuevas features
- ✅ Testing más simple
- ✅ Preparado para microservicios

**Negativas**:
- ❌ Más boilerplate inicial (más archivos/carpetas)
- ❌ Curva de aprendizaje para desarrolladores nuevos
- ❌ Puede ser "over-engineering" para features muy simples

### Referencias
- [Clean Architecture by Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Clean Architecture](https://github.com/ResoCoder/flutter-tdd-clean-architecture-course)

---

## ADR-002: Manejo de Errores con Result<T>

**Fecha**: Octubre 2025  
**Estado**: Aprobado

### Contexto
Necesitamos una forma consistente de manejar errores en toda la aplicación, especialmente en operaciones asíncronas (llamadas a API, BD).

### Decisión
Usar el tipo `Result<T>` (inspirado en Rust y el patrón Either de programación funcional) en lugar de excepciones:
```dart
sealed class Result<T> {
  const Result();
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  });
}
```

### Justificación
1. **Errores explícitos**: El tipo de retorno indica claramente que puede fallar
2. **No hay excepciones silenciosas**: El compilador obliga a manejar ambos casos
3. **Composición funcional**: Fácil encadenar operaciones con `map()` y `mapAsync()`
4. **Sin dependencias externas**: No requiere paquetes como `dartz`

### Alternativas Consideradas
- **Try-catch tradicional**: Excepciones pueden ser silenciadas
- **Paquete dartz**: Agrega dependencia externa y curva de aprendizaje
- **Callbacks con error**: Anticuado y difícil de mantener

### Consecuencias
**Positivas**:
- ✅ Errores imposibles de ignorar
- ✅ Código más predecible
- ✅ Fácil testear casos de error

**Negativas**:
- ❌ Más verboso que try-catch simple
- ❌ Desarrolladores deben aprender el patrón

---

## ADR-003: Monolito Modular como Estado Inicial

**Fecha**: Octubre 2025  
**Estado**: Aprobado

### Contexto
El proyecto es una demo para un pueblo pequeño. Debemos decidir entre:
- Empezar con microservicios desde el inicio
- Usar un monolito modular y migrar después si es necesario

### Decisión
**Mantener arquitectura monolítica modular** con estas características:
- Una sola base de datos (compartida)
- Backend en un solo servidor (actualmente PHP)
- Flutter app consume APIs del monolito
- **PERO**: Código organizado en módulos independientes (features) con Clean Architecture

### Justificación
1. **Simplicidad**: Más rápido desarrollar y desplegar
2. **Recursos limitados**: Equipo pequeño, presupuesto de demo
3. **Tráfico bajo**: Proyecto para un pueblo, no millones de usuarios
4. **Preparación futura**: Clean Architecture facilita migración a microservicios

### Cuándo Revisar
Reevaluar esta decisión si:
- Más de 50,000 usuarios activos
- Necesidad de escalar servicios de forma independiente
- Equipos de desarrollo crecen (más de 10 devs)
- Tecnologías heterogéneas (ej. IA requiere Python)

### Consecuencias
**Positivas**:
- ✅ Rápido time-to-market
- ✅ Menos complejidad operacional
- ✅ Costos de infraestructura bajos

**Negativas**:
- ❌ Escalabilidad limitada (pero suficiente para demo)
- ❌ Un bug puede afectar todo el sistema

### Plan de Migración
Si el proyecto escala, seguir [Guía de Migración a Microservicios](./MIGRATION_TO_MICROSERVICES.md).

---

## ADR-004: Inyección de Dependencias con Service Locator

**Fecha**: Octubre 2025  
**Estado**: Aprobado

### Contexto
Necesitamos gestionar dependencias entre capas (repositorios, datasources, use cases).

### Decisión
Usar patrón **Service Locator** simple implementado manualmente:
```dart
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  
  ConductorRepository get conductorRepository => _conductorRepository;
  // ...
}
```

### Justificación
1. **Simple**: No requiere paquetes externos
2. **Suficiente para MVP**: El proyecto es pequeño
3. **Migrable**: Fácil cambiar a get_it o injectable después

### Alternativas Consideradas
- **get_it**: Más robusto pero agrega dependencia
- **injectable + get_it**: Generación de código, overhead para proyecto pequeño
- **Provider puro**: Mezclado con gestión de estado UI

### Consecuencias
**Positivas**:
- ✅ Fácil de entender
- ✅ Sin dependencias externas

**Negativas**:
- ❌ Manual (no genera código)
- ❌ Puede volverse complejo si el proyecto crece

**Nota**: Si el proyecto escala, migrar a `get_it` + `injectable`.

---

## ADR-005: Base de Datos Compartida Inicial

**Fecha**: Octubre 2025  
**Estado**: Aprobado

### Contexto
En una arquitectura de microservicios, cada servicio debería tener su propia BD. Sin embargo, somos un monolito ahora.

### Decisión
Usar **una sola base de datos compartida** (actualmente MySQL/PostgreSQL) con:
- Esquemas/tablas organizadas por dominio
- Prefijos en tablas para facilitar migración futura:
  - `conductor_profiles`, `conductor_trips`
  - `user_accounts`, `user_sessions`
  - `map_routes`, `map_cache`

### Justificación
1. **Simplicidad**: Más fácil gestionar una BD
2. **Transacciones**: Operaciones ACID entre módulos
3. **Migración futura**: Prefijos facilitan separar después

### Plan de Migración (futuro)
Cuando migremos a microservicios:
1. Crear BDs separadas por servicio
2. Migrar esquemas:
   ```sql
   -- Mover conductor_* a conductor_db
   CREATE DATABASE conductor_db;
   INSERT INTO conductor_db.profiles SELECT * FROM Viax_db.conductor_profiles;
   ```
3. Usar eventos para sincronización entre servicios

### Consecuencias
**Positivas**:
- ✅ Simple para desarrollo
- ✅ Rápido para queries cross-module

**Negativas**:
- ❌ Acoplamiento entre módulos
- ❌ No escala independientemente

---

## ADR-006: URLs Configurables para Microservicios

**Fecha**: Octubre 2025  
**Estado**: Aprobado

### Contexto
Actualmente usamos URLs hardcodeadas en datasources. Necesitamos preparar para microservicios.

### Decisión
Centralizar configuración en `core/config/app_config.dart`:
```dart
class AppConfig {
  static const String conductorServiceUrl = '$baseUrl/conductor';
  static const String authServiceUrl = '$baseUrl/auth';
  // ...
}
```

Y usar variables de entorno para diferentes ambientes.

### Justificación
1. **Preparación**: Fácil cambiar URLs cuando migremos
2. **Ambientes**: Dev, staging, prod con diferentes endpoints
3. **Centralizado**: Un solo lugar para cambiar configuración

### Consecuencias
**Positivas**:
- ✅ Migración a microservicios es cambiar URLs
- ✅ Configuración clara

**Negativas**:
- ❌ Requiere disciplina para usar siempre AppConfig

---

## ADR-007: Provider para Gestión de Estado UI

**Fecha**: Octubre 2025  
**Estado**: Aprobado

### Contexto
Necesitamos gestión de estado para UI. Opciones: Provider, BLoC, Riverpod, GetX.

### Decisión
Usar **Provider** con **ChangeNotifier**.

### Justificación
1. **Simple**: Fácil de entender para equipo pequeño
2. **Oficial**: Recomendado por el equipo de Flutter
3. **Suficiente**: El proyecto no requiere complejidad de BLoC

### Alternativas Consideradas
- **BLoC**: Más robusto pero complejo para MVP
- **Riverpod**: Mejora de Provider pero requiere aprendizaje
- **GetX**: Mágico, difícil de debuggear

### Consecuencias
**Positivas**:
- ✅ Curva de aprendizaje baja
- ✅ Integrado con Flutter

**Negativas**:
- ❌ Menos escalable que BLoC
- ❌ Testing más complejo que Riverpod

**Nota**: Si el proyecto crece, migrar a **Riverpod** o **BLoC**.

---

## Plantilla para Nuevas ADRs

```markdown
## ADR-XXX: Título de la Decisión

**Fecha**: YYYY-MM-DD  
**Estado**: [Propuesto | Aprobado | Rechazado | Obsoleto]  
**Autores**: Nombre

### Contexto
¿Qué problema estamos resolviendo?

### Decisión
¿Qué decidimos hacer?

### Justificación
¿Por qué esta es la mejor opción?

### Alternativas Consideradas
¿Qué otras opciones evaluamos?

### Consecuencias
**Positivas**:
- ✅ ...

**Negativas**:
- ❌ ...

### Referencias
- Enlaces a docs, artículos, etc.
```

---

**Última actualización**: Octubre 2025  
**Versión**: 1.0.0

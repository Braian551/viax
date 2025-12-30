# Módulo Conductor - Viax

## Descripción
Módulo completo para la gestión de conductores en la aplicación Viax. Incluye pantallas, servicios, providers y backend completo.

## Estructura del Módulo

```
lib/src/features/conductor/
├── models/
│   └── conductor_model.dart          # Modelo de datos del conductor
├── providers/
│   └── conductor_provider.dart       # Provider para estado del conductor
├── services/
│   └── conductor_service.dart        # Servicios HTTP para conductor
└── presentation/
    ├── screens/
    │   └── conductor_home_screen.dart # Pantalla principal del conductor
    └── widgets/
        ├── conductor_stats_card.dart  # Widget de estadísticas
        └── viaje_activo_card.dart     # Widget de viaje activo
```

## Backend (PHP)

```
viax/backend/conductor/
├── get_info.php                    # Obtener información del conductor
├── get_viajes_activos.php          # Obtener viajes en curso
├── get_estadisticas.php            # Obtener estadísticas del día
├── get_historial.php               # Obtener historial de viajes
├── get_ganancias.php               # Obtener ganancias por período
├── actualizar_disponibilidad.php   # Cambiar estado disponible/no disponible
└── actualizar_ubicacion.php        # Actualizar ubicación en tiempo real
```

## Características

### Pantalla Principal (ConductorHomeScreen)
- **Dashboard moderno** con diseño glassmorphism
- **Switch de disponibilidad** en el AppBar para activar/desactivar recepción de viajes
- **Estadísticas en tiempo real**:
  - Viajes del día
  - Ganancias del día
  - Calificación promedio
  - Horas trabajadas
- **Viajes activos** con información completa del cliente y destino
- **Navegación por pestañas**: Inicio, Viajes, Ganancias, Perfil

### Provider (ConductorProvider)
- Gestión de estado del conductor
- Carga de información del conductor
- Actualización de disponibilidad
- Actualización de ubicación en tiempo real
- Gestión de viajes activos

### Servicios Backend
Todos los endpoints están en `http://10.0.2.2/viax/backend/conductor/`

#### GET /get_info.php
**Parámetros**: `conductor_id`
**Respuesta**: Información completa del conductor (datos personales, vehículo, licencia, etc.)

#### GET /get_viajes_activos.php
**Parámetros**: `conductor_id`
**Respuesta**: Lista de viajes en estado activo (en_camino, en_progreso, por_iniciar)

#### GET /get_estadisticas.php
**Parámetros**: `conductor_id`
**Respuesta**: Estadísticas del día actual

#### GET /get_historial.php
**Parámetros**: `conductor_id`, `page`, `limit`
**Respuesta**: Historial paginado de viajes completados

#### GET /get_ganancias.php
**Parámetros**: `conductor_id`, `fecha_inicio`, `fecha_fin`
**Respuesta**: Ganancias por período con desglose diario

#### POST /actualizar_disponibilidad.php
**Body**: `{ conductor_id, disponible, latitud?, longitud? }`
**Respuesta**: Confirmación de actualización

#### POST /actualizar_ubicacion.php
**Body**: `{ conductor_id, latitud, longitud }`
**Respuesta**: Confirmación de actualización

## Migraciones

### Migración 002: Campos adicionales para conductor
Ubicación: `viax/backend/migrations/002_conductor_fields.sql`

Agrega los siguientes campos a `detalles_conductor`:
- `disponible`: Estado de disponibilidad
- `latitud_actual`, `longitud_actual`: Ubicación en tiempo real
- `ultima_actualizacion`: Timestamp de última actualización
- `total_viajes`: Contador de viajes completados
- `estado_verificacion`: Estado de verificación de documentos
- Índices para optimizar búsquedas

### Ejecutar Migraciones
```bash
cd viax/backend
php migrations/run_migrations.php
```

## Flujo de Autenticación

1. Usuario conductor inicia sesión en `login_screen.dart`
2. Backend retorna `tipo_usuario = 'conductor'`
3. `AuthWrapper` detecta el tipo y redirige a `/conductor/home`
4. Se carga `ConductorHomeScreen` con los datos del usuario
5. `ConductorProvider` carga información adicional del conductor

## Rutas

Definidas en `route_names.dart`:
- `/conductor/home` - Pantalla principal
- `/conductor/trips` - Historial de viajes
- `/conductor/earnings` - Ganancias
- `/conductor/profile` - Perfil del conductor
- `/conductor/vehicle` - Información del vehículo

## Uso del Provider

```dart
// En main.dart, el provider ya está registrado
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ConductorProvider()),
  ],
)

// En cualquier widget
final conductorProvider = Provider.of<ConductorProvider>(context);

// Cargar información
await conductorProvider.loadConductorInfo(conductorId);

// Cambiar disponibilidad
await conductorProvider.toggleDisponibilidad(
  conductorId: conductorId,
  latitud: currentLat,
  longitud: currentLng,
);

// Acceder a datos
final conductor = conductorProvider.conductor;
final disponible = conductorProvider.disponible;
final estadisticas = conductorProvider.estadisticas;
```

## Próximas Mejoras

- [ ] Implementar pantalla de historial de viajes
- [ ] Implementar pantalla de ganancias con gráficos
- [ ] Implementar pantalla de perfil del conductor
- [ ] Agregar notificaciones push para nuevas solicitudes
- [ ] Implementar navegación en tiempo real con Mapbox
- [ ] Agregar chat en tiempo real con el cliente
- [ ] Implementar sistema de calificaciones bidireccional

## Notas Importantes

1. El conductor debe tener un registro en `detalles_conductor` para acceder al módulo
2. La disponibilidad se actualiza automáticamente al cerrar la app (pendiente implementar)
3. La ubicación se debe actualizar cada X segundos cuando esté disponible (pendiente implementar)
4. Todos los endpoints requieren autenticación (pendiente implementar middleware)

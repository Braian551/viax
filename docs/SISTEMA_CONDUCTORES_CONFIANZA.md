# Sistema de Conductores de Confianza

## Descripción General

El sistema de Conductores de Confianza permite a los usuarios establecer relaciones de preferencia con conductores específicos, mejorando la experiencia de servicio al priorizar conductores conocidos y de confianza.

## Características

### 1. Conductores Favoritos
- Los usuarios pueden marcar/desmarcar conductores como favoritos
- Los favoritos aparecen primero en las búsquedas de solicitudes
- Bonus de +100 puntos en el ConfianzaScore

### 2. ConfianzaScore
Puntaje calculado automáticamente basado en:

| Componente | Peso | Descripción |
|------------|------|-------------|
| Viajes Repetidos | 30% | Historial de viajes entre usuario y conductor |
| Calificación Conductor | 25% | Promedio de calificaciones del conductor |
| Calificación Usuario | 15% | Calificaciones que el usuario da al conductor |
| Proximidad Zona | 20% | Cercanía a zonas frecuentes de recogida |
| Popularidad Vecinos | 10% | Uso del conductor por usuarios cercanos |

**Bonus adicionales:**
- +100 puntos por ser favorito
- +5 puntos por viaje reciente (últimos 7 días)

### 3. Niveles de Confianza

| Nivel | Score | Descripción |
|-------|-------|-------------|
| Muy Alto | ≥150 | Conductor de extrema confianza |
| Alto | ≥100 | Conductor favorito o muy confiable |
| Medio | ≥50 | Conductor conocido |
| Bajo | ≥20 | Algunos viajes previos |
| Nuevo | <20 | Sin historial |

## Estructura de Archivos

### Backend (PHP)

```
backend/
├── confianza/
│   ├── ConfianzaService.php      # Servicio principal de cálculo
│   └── calculate_score.php       # Endpoint para calcular score
├── migrations/
│   └── 001_create_conductores_confianza_tables.sql
└── user/
    ├── toggle_favorite_driver.php    # Marcar/desmarcar favorito
    ├── get_favorite_drivers.php      # Obtener lista de favoritos
    └── rate_trip.php                 # (modificado) Actualiza historial
```

### Flutter (Dart)

```
lib/src/features/
├── conductor/
│   ├── models/
│   │   └── confianza_model.dart          # Modelos de datos
│   ├── services/
│   │   └── trusted_driver_service.dart   # Servicio HTTP
│   └── presentation/
│       └── widgets/
│           └── favorite_driver_widgets.dart  # Widgets UI
└── user/
    └── presentation/
        └── screens/
            └── favorite_drivers_screen.dart  # Pantalla de favoritos
```

## Base de Datos

### Nueva Tabla: conductores_favoritos

```sql
CREATE TABLE conductores_favoritos (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id BIGINT UNSIGNED NOT NULL,
  conductor_id BIGINT UNSIGNED NOT NULL,
  es_favorito TINYINT(1) DEFAULT 1,
  fecha_marcado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_desmarcado TIMESTAMP NULL,
  UNIQUE KEY (usuario_id, conductor_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
  FOREIGN KEY (conductor_id) REFERENCES usuarios(id) ON DELETE CASCADE
);
```

### Nueva Tabla: historial_confianza

```sql
CREATE TABLE historial_confianza (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id BIGINT UNSIGNED NOT NULL,
  conductor_id BIGINT UNSIGNED NOT NULL,
  total_viajes INT UNSIGNED DEFAULT 0,
  viajes_completados INT UNSIGNED DEFAULT 0,
  viajes_cancelados INT UNSIGNED DEFAULT 0,
  suma_calificaciones_conductor DECIMAL(10,2) DEFAULT 0,
  suma_calificaciones_usuario DECIMAL(10,2) DEFAULT 0,
  total_calificaciones INT UNSIGNED DEFAULT 0,
  ultimo_viaje_fecha TIMESTAMP NULL,
  score_confianza DECIMAL(5,2) DEFAULT 0.00,
  zona_frecuente_lat DECIMAL(10,8) NULL,
  zona_frecuente_lng DECIMAL(11,8) NULL,
  UNIQUE KEY (usuario_id, conductor_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
  FOREIGN KEY (conductor_id) REFERENCES usuarios(id) ON DELETE CASCADE
);
```

## API Endpoints

### POST /user/toggle_favorite_driver.php
Marca o desmarca un conductor como favorito.

**Request:**
```json
{
  "usuario_id": 1,
  "conductor_id": 7
}
```

**Response:**
```json
{
  "success": true,
  "es_favorito": true,
  "message": "Conductor agregado a favoritos"
}
```

### GET/POST /user/get_favorite_drivers.php
Obtiene lista de conductores favoritos.

**Request:**
```json
{
  "usuario_id": 1
}
```

**Response:**
```json
{
  "success": true,
  "total": 2,
  "favoritos": [
    {
      "conductor_id": 7,
      "nombre": "Juan",
      "apellido": "Pérez",
      "foto_perfil": null,
      "vehiculo": {
        "tipo": "motocicleta",
        "marca": "Toyota",
        "modelo": "Corolla",
        "placa": "ABC123"
      },
      "calificacion_promedio": 4.8,
      "total_viajes": 150,
      "viajes_contigo": 5,
      "score_confianza": 45.5
    }
  ]
}
```

### POST /confianza/calculate_score.php
Calcula el ConfianzaScore entre usuario y conductor.

**Request:**
```json
{
  "usuario_id": 1,
  "conductor_id": 7,
  "latitud": 6.2546,
  "longitud": -75.5395
}
```

**Response:**
```json
{
  "success": true,
  "score_confianza": 145.5,
  "es_favorito": true,
  "desglose": {
    "viajes_juntos": 5,
    "total_viajes_conductor": 150,
    "calificacion_conductor": 4.8,
    "ultimo_viaje": "2025-12-01 10:30:00",
    "bonus_favorito": 100
  },
  "nivel_confianza": {
    "nivel": "alto",
    "descripcion": "Conductor favorito o muy confiable"
  }
}
```

## Modificación a Lógica de Asignación

El endpoint `get_solicitudes_pendientes.php` fue modificado para:

1. **Incluir datos de confianza** en las solicitudes retornadas
2. **Priorizar solicitudes** en el siguiente orden:
   - Primero: Usuarios que marcaron al conductor como favorito
   - Segundo: Por score de confianza más alto
   - Tercero: Por distancia (fallback original)

La respuesta de solicitudes ahora incluye:

```json
{
  "id": 1,
  "usuario_id": 6,
  "nombre_usuario": "Juan",
  ...
  "confianza": {
    "score": 45.5,
    "score_total": 145.5,
    "viajes_previos": 5,
    "es_favorito": true
  }
}
```

## Uso en Flutter

### Marcar como favorito

```dart
import 'package:viax/src/features/conductor/services/trusted_driver_service.dart';

// Toggle favorito
final esFavorito = await TrustedDriverService.toggleFavorite(
  usuarioId: 1,
  conductorId: 7,
);
```

### Widget de botón favorito

```dart
import 'package:viax/src/features/conductor/presentation/widgets/favorite_driver_widgets.dart';

FavoriteDriverButton(
  usuarioId: 1,
  conductorId: 7,
  initialValue: false,
  onChanged: () {
    // Refrescar UI
  },
)
```

### Indicador de nivel de confianza

```dart
TrustLevelIndicator(
  confianza: ConfianzaInfo(
    score: 45.5,
    scoreTotal: 145.5,
    viajesPrevios: 5,
    esFavorito: true,
  ),
  showLabel: true,
)
```

## Instalación

1. **Ejecutar migración SQL:**
   ```bash
   mysql -u root -p viax < backend/migrations/001_create_conductores_confianza_tables.sql
   ```

2. **Verificar que los archivos PHP están en su lugar**

3. **No se requieren cambios en pubspec.yaml** - Solo se usan dependencias existentes

## Consideraciones de Rendimiento

- Los índices SQL están optimizados para las consultas frecuentes
- El cálculo del ConfianzaScore se realiza en tiempo real pero con fallback graceful
- Las tablas de confianza usan LEFT JOIN para no bloquear si no existen

## Compatibilidad

- **MySQL 5.7+** / **MariaDB 10.2+**
- **PostgreSQL 12+** (ver sintaxis alternativa en migración)
- **Flutter 3.0+**
- **PHP 7.4+**

# Corrección: Error 500 en Historial de Viajes del Conductor

## Problema
El endpoint `get_historial.php` generaba un error 500 al intentar obtener el historial de viajes del conductor. La aplicación Flutter mostraba el mensaje "Error del servidor: 500".

## Causa Raíz
El código intentaba acceder a columnas que no existían en la base de datos:

1. **`conductor_id` en `solicitudes_servicio`**: La tabla no tiene esta columna directamente. La relación conductor-solicitud se maneja a través de la tabla `asignaciones_conductor`.

2. **Columnas inexistentes**: Se referenciaba a columnas como:
   - `usuario_id` → Debe ser `cliente_id`
   - `ubicacion_origen_id` → Debe ser `ubicacion_recogida_id`
   - `precio_estimado`, `precio_final` → No existen en la tabla actual
   - `comentario` → Debe ser `comentarios` (plural)

## Solución Implementada

### Cambios en `get_historial.php`

#### 1. Query de conteo corregido
```php
// ANTES (incorrecto)
SELECT COUNT(*) as total
FROM solicitudes_servicio
WHERE conductor_id = :conductor_id
AND estado = 'completada'

// DESPUÉS (correcto)
SELECT COUNT(*) as total
FROM solicitudes_servicio s
INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
WHERE ac.conductor_id = :conductor_id
AND s.estado IN ('completada', 'entregado')
```

#### 2. Query principal corregido
```php
// Se agregó JOIN con asignaciones_conductor
INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id

// Se corrigieron los nombres de columnas
- s.cliente_id (no usuario_id)
- s.direccion_recogida (no uo.direccion)
- s.direccion_destino (no ud.direccion)
- s.distancia_estimada as distancia_km
- s.tiempo_estimado as duracion_estimada
- s.solicitado_en as fecha_solicitud
- s.completado_en as fecha_completado
- c.comentarios as comentario (no c.comentario)

// Se corrigió el JOIN con calificaciones
LEFT JOIN calificaciones c ON s.id = c.solicitud_id 
  AND c.usuario_calificado_id = :conductor_id2
```

#### 3. Se agregaron valores por defecto para precios
```php
0 as precio_estimado,
0 as precio_final
```

### Estructura de Base de Datos Utilizada

```sql
-- Tabla principal de solicitudes
solicitudes_servicio
├── id
├── cliente_id (FK -> usuarios)
├── direccion_recogida
├── direccion_destino
├── distancia_estimada
├── tiempo_estimado
├── estado
├── solicitado_en
└── completado_en

-- Tabla de asignación conductor-solicitud
asignaciones_conductor
├── id
├── solicitud_id (FK -> solicitudes_servicio)
├── conductor_id (FK -> usuarios)
├── asignado_en
└── estado

-- Tabla de calificaciones
calificaciones
├── id
├── solicitud_id (FK -> solicitudes_servicio)
├── usuario_calificador_id (FK -> usuarios)
├── usuario_calificado_id (FK -> usuarios)
├── calificacion (1-5)
└── comentarios
```

## Resultado
✅ El endpoint ahora funciona correctamente y retorna:
```json
{
  "success": true,
  "viajes": [
    {
      "id": 1,
      "tipo_servicio": "transporte",
      "estado": "completada",
      "distancia_km": "8.50",
      "duracion_estimada": 25,
      "fecha_solicitud": "2025-10-24 16:28:46",
      "fecha_completado": "2025-10-24 16:28:46",
      "origen": "Carrera 18B, Llanaditas",
      "destino": "Parque Lleras, El Poblado",
      "cliente_nombre": "braian",
      "cliente_apellido": "oquendo",
      "calificacion": 5,
      "comentario": "Excelente conductor!",
      "precio_estimado": 0,
      "precio_final": 0
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "total_pages": 1
  },
  "message": "Historial obtenido exitosamente"
}
```

## Testing
Para probar el endpoint:
```bash
curl "http://localhost/viax/backend/conductor/get_historial.php?conductor_id=7&page=1&limit=20"
```

## Archivos Modificados
- `viax/backend/conductor/get_historial.php` ✅

## Fecha de Corrección
24 de octubre de 2025

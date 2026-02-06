# Sistema de Reseñas Mejorado - Prevención de Duplicados

## Resumen
Se implementó un sistema robusto para prevenir que un usuario califique múltiples veces el mismo viaje. Cuando un usuario envía una nueva calificación para un viaje ya calificado, el sistema **reemplaza** automáticamente la calificación anterior en lugar de crear una duplicada.

## Cambios Realizados

### 🗄️ Base de Datos

#### Migración Ejecutada
- **Archivo**: `backend/migrations/add_unique_constraint_calificaciones.php`
- **Estado**: ✅ Ejecutada exitosamente

**Cambios aplicados:**
1. ✅ UNIQUE constraint `unique_calificacion_por_usuario_solicitud` creado
   - Previene duplicados en `(solicitud_id, usuario_calificador_id)`
2. ✅ Índice `idx_calificaciones_solicitud_calificador` creado
   - Mejora el rendimiento de búsqueda de calificaciones existentes
3. ✅ No se encontraron duplicados existentes

### 🔧 Backend (PHP)

#### `backend/rating/submit_rating.php`
**Mejoras implementadas:**

1. **Verificación de calificación existente**
   ```php
   SELECT id, calificacion as calificacion_anterior, comentarios
   FROM calificaciones
   WHERE solicitud_id = ? AND usuario_calificador_id = ?
   ```

2. **Lógica UPDATE vs INSERT**
   - Si existe: Actualiza calificación, comentario y timestamp
   - Si no existe: Crea nueva calificación con `INSERT ... ON CONFLICT`

3. **Respaldo con INSERT ... ON CONFLICT**
   ```php
   INSERT INTO calificaciones (...)
   ON CONFLICT (solicitud_id, usuario_calificador_id) 
   DO UPDATE SET calificacion = EXCLUDED.calificacion, ...
   ```

4. **Respuesta mejorada**
   ```json
   {
     "success": true,
     "message": "Calificación actualizada correctamente",
     "updated": true,
     "previous_rating": 4,
     "current_rating": 5,
     "nuevo_promedio": 4.8
   }
   ```

### 📱 Frontend (Flutter)

#### `lib/src/global/services/rating_service.dart`
**Nuevas características:**

1. **Nueva clase `RatingResult`**
   ```dart
   class RatingResult {
     final bool success;
     final String message;
     final bool wasUpdated;
     final int? previousRating;
     final int? currentRating;
     final double? nuevoPromedio;
   }
   ```

2. **Logs mejorados**
   - `📝 Enviando calificación`
   - `♻️ Calificación actualizada (anterior: X)`
   - `✅ Nueva calificación creada`

3. **Documentación actualizada**
   - Explica la lógica de reemplazo automático

#### `lib/src/global/widgets/trip_completion/trip_completion_screen.dart`
**Mejoras en UI:**

1. **Callback modificado**
   ```dart
   // Antes: Future<bool> Function(int rating, String? comentario)
   // Ahora: Future<Map<String, dynamic>> Function(int rating, String? comentario)
   ```

2. **Estado de actualización**
   ```dart
   bool _ratingWasUpdated = false;
   ```

3. **Mensaje diferenciado**
   - ✅ Nueva: "¡Gracias por tu calificación!"
   - ♻️ Actualizada: "¡Calificación actualizada!"

4. **Ícono dinámico**
   - Nueva: `Icons.check_circle_rounded`
   - Actualizada: `Icons.update_rounded`

#### Pantallas actualizadas
- `lib/src/features/conductor/presentation/screens/active_trip_screen.dart`
- `lib/src/features/user/presentation/screens/user_active_trip_screen.dart`

Ambas ahora retornan el resultado completo del servicio en lugar de solo un booleano.

## Flujo de Funcionamiento

### Escenario 1: Primera Calificación
1. Usuario califica conductor/cliente con 5 estrellas
2. Backend verifica: no existe calificación previa
3. Se crea nueva entrada en `calificaciones`
4. Respuesta: `{"success": true, "updated": false}`
5. UI muestra: "¡Gracias por tu calificación!" ✅

### Escenario 2: Calificación Repetida
1. Usuario vuelve a calificar el mismo viaje con 4 estrellas
2. Backend verifica: existe calificación previa (5 estrellas)
3. Se actualiza entrada existente en `calificaciones`
4. Respuesta: `{"success": true, "updated": true, "previous_rating": 5}`
5. UI muestra: "¡Calificación actualizada!" ♻️

### Escenario 3: Condición de Carrera (raro)
1. Dos requests simultáneos del mismo usuario
2. Primera request: INSERT exitoso
3. Segunda request: `ON CONFLICT` detecta duplicado → UPDATE
4. Resultado final: Solo una calificación en BD

## Ventajas

✅ **Previene duplicados** a nivel de base de datos  
✅ **Mejor experiencia de usuario** - puede cambiar su opinión  
✅ **Promedios correctos** - no se inflan con duplicados  
✅ **Performance mejorado** - índice en búsquedas frecuentes  
✅ **Feedback claro** - usuario sabe si actualizó o creó nueva  
✅ **Robusto ante condiciones de carrera** - `ON CONFLICT` como respaldo  

## Testing

### Para probar el sistema:

1. **Completar un viaje**
2. **Calificar al otro usuario** (5 estrellas)
3. **Volver a ingresar al viaje** (si es posible en desarrollo)
4. **Calificar nuevamente** (4 estrellas)
5. **Verificar en BD**:
   ```sql
   SELECT * FROM calificaciones 
   WHERE solicitud_id = X AND usuario_calificador_id = Y;
   ```
   Debe haber solo 1 registro con calificación = 4

6. **Verificar promedio actualizado**:
   ```sql
   SELECT calificacion_promedio 
   FROM detalles_conductor 
   WHERE usuario_id = Y;
   ```

## Notas Técnicas

- El `UNIQUE` constraint se aplica en `(solicitud_id, usuario_calificador_id)`
- El timestamp `creado_en` se actualiza a `NOW()` en cada UPDATE
- El promedio se recalcula automáticamente después de cada calificación
- Compatible con PostgreSQL 9.5+ (requiere `ON CONFLICT`)

## Migración Manual (si es necesario)

Si necesitas ejecutar la migración en otro ambiente:

```bash
php backend/migrations/add_unique_constraint_calificaciones.php
```

O directamente en PostgreSQL:

```sql
-- Limpiar duplicados (si existen)
DELETE FROM calificaciones 
WHERE id NOT IN (
  SELECT MAX(id) 
  FROM calificaciones 
  GROUP BY solicitud_id, usuario_calificador_id
);

-- Agregar constraint
ALTER TABLE calificaciones 
ADD CONSTRAINT unique_calificacion_por_usuario_solicitud 
UNIQUE (solicitud_id, usuario_calificador_id);

-- Agregar índice (opcional pero recomendado)
CREATE INDEX idx_calificaciones_solicitud_calificador 
ON calificaciones (solicitud_id, usuario_calificador_id);
```

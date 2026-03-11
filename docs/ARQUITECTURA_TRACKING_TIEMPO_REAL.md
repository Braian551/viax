# Arquitectura Tracking en Tiempo Real (Viax)

## Objetivo
Migrar de un modelo intensivo en polling a un modelo push de baja latencia, tolerante a ruido GPS y escalable horizontalmente.

## Resumen de diseño
- Conductor envia actualizaciones GPS cada 2-4 segundos.
- Backend procesa incrementalmente distancia y tiempo en Redis (estado realtime).
- Pasajero consume updates por SSE (suscripcion), con fallback a polling cada 10-15s.
- PostgreSQL se usa para persistencia historica y metricas finales, no como fuente realtime.

## Flujo extremo a extremo
1. Driver App -> `POST /driver/tracking/update`
2. API valida/filtra punto y actualiza:
   - `trip:{trip_id}:state`
   - `trip:{trip_id}:metrics`
3. API publica en `trip_updates:{trip_id}`
4. Passenger App suscrita por SSE (`GET /user/stream_trip_updates.php`) recibe update inmediato.
5. Persistencia por lotes a PostgreSQL cada 10 puntos o 10 segundos.

## Claves Redis
- `trip:{trip_id}:state`
  - Estado publico de tracking realtime.
  - TTL: 2 horas.
- `trip:{trip_id}:metrics`
  - Acumulados: distancia, tiempo, velocidad promedio, ultimo punto.
  - TTL: 2 horas.
- `trip_tracking_latest:{trip_id}`
  - Compatibilidad con endpoints existentes.
- `driver_location:{driver_id}`
  - Ubicacion fresca de conductor para matching/estado.
- `trip:{trip_id}:buffer_points`
  - Buffer de puntos para flush por lotes a PostgreSQL.

## Filtros fisicos y tolerancia de latencia
- Rechazo/cap de velocidad: max 140 km/h.
- Si `time_delta > 30s`, se limita distancia por fisica:
  - `max_dist = 140 km/h * time_delta`
- Limite de seguridad de ruta:
  - `distance_total <= planned_route_distance * 1.5`

## Rate limiting
- Se rechaza update de conductor si llega en menos de 1 segundo del anterior.

## Observabilidad minima
Se contabilizan anomalias por viaje:
- `gps_jump`
- `speed_overflow`
- `invalid_timestamp`
- `distance_cap`

## Persistencia PostgreSQL
No se persiste cada punto en forma sincrona por request.
Se agrupa por lotes:
- cada 10 puntos
- o cada 10 segundos

Tabla recomendada/actual:
- `viaje_tracking_realtime` (historial)
- `viaje_resumen_tracking` (agregados)
- `solicitudes_servicio` (metricas visibles/finales)

## Fallback de pasajero
En cliente Flutter:
- Primario: SSE (`/user/stream_trip_updates.php`)
- Fallback automatico: polling long-polling cada 10-15s

## Finalizacion de viaje
Al finalizar:
- `metrics_locked = true`
- Persistir en PostgreSQL:
  - `distance_final_km`
  - `time_final_sec`
  - `avg_speed`
- Expirar/eliminar claves Redis de viaje.

## Garantia de consistencia
Se prioriza coherencia entre:
- tracking conductor
- vista pasajero
- resumen final
- motor de precios

Se bloquean estados imposibles como:
- distancia alta con tiempo cero (ej: 61 km en 0 s)

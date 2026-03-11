# Arquitectura Tracking en Tiempo Real (Viax) - Fase 2

## Objetivo
Consolidar un tracking push de baja latencia y bajo costo operativo, con consistencia canónica entre ubicación, métricas y precio final.

## Flujo end-to-end
1. Conductor envía punto a POST /driver/tracking/update.php.
2. Backend aplica map matching (si hay API key), valida física/timestamps y actualiza Redis.
3. Backend publica evento en trip_updates:{trip_id} y agrega evento al stream trip_tracking_stream (XADD).
4. Pasajero recibe por SSE en GET /user/stream_trip_updates.php.
5. Worker de Streams consume con XREADGROUP y persiste en lotes a PostgreSQL.

## 1) Interpolación de posición en cliente
Problema: el marcador "saltaba" cada 2-4s.

Solución en Flutter:
- Se agregó interpolación con AnimationController + Tween<LatLng> + CurvedAnimation.
- Cada punto nuevo anima transición entre posición previa y nueva en 1.2-1.8s.
- Si llega otro punto antes de terminar, la animación se reinicia desde la posición actual renderizada.

Beneficio:
- Movimiento visual continuo, sin "teletransporte" del marcador.

## 2) Optimización de envío en app conductor
Reglas de envío inteligente:
- Enviar si distancia > 5m, o cambio de rumbo > 10 grados, o cambio de velocidad significativo.
- Enviar forzado si ya pasaron 10s desde último envío.
- Intervalo adaptativo por velocidad:
  - < 5 km/h: 8s
  - < 20 km/h: 4s
  - >= 20 km/h: 2s

Resultado:
- Menos tráfico de red y menos carga de backend cuando el vehículo está quieto.

## 3) Modelo Redis compacto y TTL
Claves activas:
- trip:{trip_id}:state
- trip:{trip_id}:metrics
- trip_updates:{trip_id}

Estructura state (compacta):
- lat
- lng
- timestamp
- speed
- heading

Estructura metrics (compacta):
- distance_km
- elapsed_time_sec
- avg_speed_kmh
- last_timestamp
- last_ts
- last_lat
- last_lng
- planned_route_km

TTL:
- 7200 segundos (2 horas) para claves de viaje.

## 4) Persistencia asíncrona con Redis Streams + worker
Request path en /driver/tracking/update.php:
- Actualiza Redis.
- Publica SSE.
- XADD en trip_tracking_stream.
- Responde inmediato.

Worker:
- Archivo: backend/scripts/trip_tracking_queue_worker.php
- Archivo productivo: backend/workers/tracking_stream_worker.php
- Estrategia de flush:
  - lote de 100 puntos, o
  - cada 3 segundos.
- Persiste en:
  - trip_tracking_points (tabla liviana)
  - con ACK explícito de mensajes en stream.

Consumer Group:
- tracking_workers

Ventajas de Streams:
- ACK por mensaje
- reintento de pendientes
- escalado horizontal con múltiples workers

## 5) Modelo PostgreSQL recomendado
Tabla principal de puntos:
- trip_tracking_points(id, trip_id, lat, lng, speed, heading, timestamp, created_at)

Índice:
- INDEX(trip_id, timestamp DESC)

Migración:
- backend/migrations/048_tracking_stream_upgrade.sql

## 6) Consistencia tracking -> pricing
Fuente canónica de métricas activas:
- trip:{trip_id}:metrics

Regla:
- El motor de precio y finalize deben priorizar distance_km y elapsed_time_sec de Redis canónico.
- No recalcular distancia en caminos paralelos para evitar desalineación de cobro.

Aplicado:
- finalize.php ahora lee métricas canónicas desde Redis antes de reconciliaciones de respaldo.

## 7) SSE hardening
SSE en /user/stream_trip_updates.php:
- keepalive cada 20s (event: keepalive)
- timeout controlado para reconexión limpia
- firma de cambios para emitir solo cuando hay diferencias reales
- payload incluye velocidad y heading para predicción cliente

## 8) Dead-reckoning en pasajero
Cuando no llega GPS nuevo:
- iniciar predicción después de 2s sin update
- ventana máxima de predicción: 6s

Modelo:
- posición_predicha = posición_última + (velocidad * delta_t * vector_heading)
- se detiene al recibir un nuevo GPS real

## 9) Fallback pasajero
Orden de prioridad en app:
1. SSE
2. Long-polling cada 15s
3. Última métrica cacheada localmente

Nota:
- Nunca se debe poll más rápido que 12s en fallback.

## 10) Rate limiting conductor mejorado
Regla:
- permitir update si delta_t >= 1s
- o si el movimiento real > 10m

Esto evita descartar puntos válidos en aceleraciones o cambios rápidos de trayectoria.

## 11) Observabilidad liviana
Contadores Redis con INCR:
- metrics:tracking_updates
- metrics:tracking_latency
- metrics:tracking_latency_count
- metrics:anomaly:gps_jump
- metrics:anomaly:speed_overflow
- metrics:anomaly:distance_cap
- metrics:anomaly:invalid_timestamp
- metrics:worker:batch_insert

También se mantiene hash por viaje:
- trip:{trip_id}:anomalies

## 12) Map matching
Implementación backend en update.php:
- API Google Roads snapToRoads (si existe API key)
- cache de snapping en Redis: gps_snap_cache:{hash}
- TTL 24h
- fallback automático a GPS crudo cuando falla API

## 13) Corrección de distancia por segmento
Cada incremento se valida con:
- velocidad máxima 140 km/h
- límite por delta de tiempo (max_distance = speed_limit * delta_time)
- descarte por timestamp regresivo

Esto evita picos que inflan distancia y precio.

## 14) Finalización y limpieza
Al cerrar viaje:
- metrics_locked = true en BD canónica
- Persisten métricas finales (distance_final, duration_final, price_final)
- Limpieza Redis del viaje:
  - trip:{trip_id}:state
  - trip:{trip_id}:metrics
  - trip:{trip_id}:anomalies

## 15) Objetivo de rendimiento
Diseño orientado a:
- 10k+ viajes concurrentes
- lecturas/escrituras O(1) en Redis
- pocas escrituras síncronas a PostgreSQL
- latencia pasajero objetivo < 400ms

## Operación
Worker recomendado en segundo plano:
- php backend/workers/tracking_stream_worker.php

Sugerencia de despliegue:
- ejecutar worker con supervisor/systemd para autorestart y monitoreo.
- referencia de supervisor: backend/workers/supervisor_tracking_worker.conf

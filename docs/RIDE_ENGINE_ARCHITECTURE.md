# Arquitectura Ride Engine (Viax)

## Objetivo
Diseñar una capa de inteligencia de viajes escalable y de bajo costo operativo sobre el stack actual (PHP + PostgreSQL + Redis + Flutter).

## Componentes principales
- Descubrimiento de conductores con Redis GEO.
- Motor ETA con cache corto y corrección histórica.
- Motor de pricing dinámico (tráfico + demanda).
- Máquina de estados estricta para viajes.
- Matching por ranking multi-factor.
- Observabilidad basada en contadores Redis.

## 1) Driver Discovery (Redis GEO)
Índice principal:
- drivers:geo

Operaciones:
- GEOADD drivers:geo lng lat driver_id
- GEOSEARCH ... BYRADIUS 5 km WITHDIST ASC

Estados en Redis:
- driver:{id}:state = available | on_trip | offline

Regla de búsqueda:
- solo candidatos con estado available.

## 2) ETA Engine
Archivo:
- backend/services/eta_service.php

Entradas:
- origen
- destino
- nivel de tráfico
- velocidad histórica

Estrategia:
- Google Routes API como fuente principal.
- Corrección por velocidad histórica de segmento/hora.
- Fallback: distancia / velocidad promedio.

Cache:
- eta_cache:{origin_hash}:{dest_hash}
- TTL 60 segundos.

Clave de velocidad histórica:
- road_speed:{road_segment}:{hour}

## 3) Dynamic Pricing Engine
Archivo:
- backend/services/pricing_service.php

Fórmula base:
- base + (distancia * tarifa_km) + (tiempo * tarifa_min)

Multiplicadores:
- tráfico = avg_speed / current_speed
- surge = active_requests / available_drivers

Resultado:
- final = base * tráfico * surge

Cache de surge:
- surge_zone:{grid_cell}
- TTL 30 segundos.

## 4) Trip State Machine
Archivo:
- backend/services/trip_state_machine.php

Estados canónicos:
- REQUESTED
- DRIVER_ASSIGNED
- DRIVER_EN_ROUTE
- DRIVER_ARRIVED
- TRIP_STARTED
- TRIP_COMPLETED
- TRIP_CANCELLED

Reglas estrictas:
- TRIP_STARTED solo después de DRIVER_ARRIVED.
- TRIP_COMPLETED solo después de TRIP_STARTED.
- transiciones inválidas se rechazan.

## 5) Matching Engine
Archivo:
- backend/services/matching_service.php

Pasos:
1. Buscar cercanos por GEOSEARCH.
2. Rankear por:
   - distancia
   - calificación
   - tasa de aceptación
3. Ofertar por prioridad.

Timeout recomendado por conductor:
- 10 segundos.

## 6) Surge por celdas (grid)
Modelo:
- zone:{lat_index}:{lng_index}

Métricas por celda:
- active_requests
- available_drivers

Cálculo:
- surge = requests / drivers
- clamp entre 1.0 y 3.0.

## 7) Modularización backend
Servicios nuevos:
- backend/services/tracking_service.php
- backend/services/driver_service.php
- backend/services/eta_service.php
- backend/services/pricing_service.php
- backend/services/matching_service.php
- backend/services/trip_state_machine.php

Principio:
- controladores delgados; lógica en servicios.

## 8) Observabilidad
Contadores Redis:
- metrics:rides_requested
- metrics:rides_completed
- metrics:driver_acceptance_rate
- metrics:eta_accuracy
- metrics:matching_latency
- metrics:matching_latency_count
- metrics:tracking_updates
- metrics:tracking_latency
- metrics:tracking_latency_count
- metrics:worker:batch_insert

## 9) Performance targets
Objetivo operativo:
- 20k viajes concurrentes.
- 100k actualizaciones de conductor/minuto.
- latencia tracking pasajero < 350 ms.
- matching < 800 ms.

Diseño:
- Redis O(1) para estado caliente.
- escritura en BD por lotes.

## 10) Base de datos
Migración recomendada:
- backend/migrations/049_ride_engine_indexes_and_archive.sql

Índices:
- solicitudes_servicio(estado)
- solicitudes_servicio(conductor_id)
- solicitudes_servicio(cliente_id)
- trip_tracking_points(trip_id, timestamp)

Archivado:
- backend/scripts/archive_tracking_points.php
- mueve datos de tracking de más de 30 días a tabla de archivo.

## 11) Despliegue y operación
1. Backup BD.
2. Ejecutar migraciones.
3. Reiniciar servicios PHP.
4. Mantener worker de streams en ejecución.
5. Monitorear counters Redis y latencias.

## Nota de costo
La arquitectura prioriza:
- cache caliente en Redis
- cálculos O(1)
- llamadas externas con timeout corto y fallback
- persistencia diferida por lotes

Esto mantiene bajo uso de CPU y costo de infraestructura.

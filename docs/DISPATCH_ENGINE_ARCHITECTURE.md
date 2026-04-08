# Arquitectura del Dispatch Engine (VIAX)

## Objetivo

Asignar solicitudes a conductores de forma rapida, justa y resiliente, con tolerancia a rechazos/no respuesta y expansion progresiva del radio de busqueda.

## Componentes principales

1. Cola de solicitudes
- Redis list: `ride_requests_queue`.
- Productor: `backend/user/create_trip_request.php` encola el `request_id`.

2. Worker de despacho
- Proceso: `backend/workers/dispatch_worker.php`.
- Consume cola con `BRPOP`.
- Para cada solicitud pendiente ejecuta rondas por radio: `2 -> 4 -> 6 -> 8 -> 10 km`.

3. Ranking de candidatos
- Servicio: `backend/services/matching_service.php`.
- Puntaje combinado por:
  - distancia (menor es mejor)
  - rating historico
  - tasa de aceptacion
  - tiempo inactivo (fairness)
  - penalizacion por carga/rechazos recientes

4. Estado y locks en Redis
- Lock de oferta por conductor: `driver:{id}:offer_lock` (TTL corto).
- Señal de aceptacion: `ride:{request_id}:accepted_driver`.
- Oferta actual: `ride:{request_id}:current_offer`.
- Candidatos cacheados: `ride:{request_id}:drivers`.
- Radio actual: `ride:{request_id}:radius`.

5. Integracion de aceptacion
- Endpoint de conductor: `backend/conductor/accept_trip_request.php`.
- Al aceptar:
  - setea `ride:{request_id}:accepted_driver`
  - libera lock de oferta del conductor
  - actualiza metricas de aceptacion

6. Descubrimiento GEO y celdas
- Servicio: `backend/services/driver_service.php`.
- Base: `drivers:geo` (Redis GEO).
- Apoyo de celdas: `grid:{x}:{y}` y metricas de zona `zone:{cell}:*`.

## Flujo operacional

1. Pasajero crea solicitud.
2. API crea registro en DB y encola `request_id`.
3. Worker toma solicitud y consulta candidatos rankeados.
4. Worker oferta secuencialmente (timeout 10s por conductor).
5. Si no hay aceptacion, intenta siguiente conductor; al agotarse, expande radio.
6. Si hay aceptacion, se cierra asignacion y persiste cache de asignado.

## Fairness y balanceo

- Prioriza conductores con mayor tiempo inactivo.
- Penaliza conductores con alta carga reciente.
- Penaliza rechazo/no respuesta recurrente para reducir spam de ofertas.

## Observabilidad minima

Contadores Redis recomendados:
- `metrics:dispatch_requests`
- `metrics:dispatch_attempts`
- `metrics:dispatch_accepts`
- `metrics:dispatch_timeouts`
- `metrics:dispatch_latency`
- `metrics:dispatch_latency_count`

KPIs derivados:
- Acceptance rate = accepts / attempts
- Timeout ratio = timeouts / attempts
- Avg dispatch latency = latency / latency_count

## Supervisor (produccion)

Ejemplo de programa para worker de despacho:

```ini
[program:viax-dispatch-worker]
command=/usr/bin/php /var/www/viax/backend/workers/dispatch_worker.php
directory=/var/www/viax/backend
autostart=true
autorestart=true
startretries=3
user=www-data
redirect_stderr=true
stdout_logfile=/var/log/supervisor/viax-dispatch-worker.log
stdout_logfile_maxbytes=20MB
stdout_logfile_backups=10
stopwaitsecs=10
```

Aplicar cambios:

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl status
```

## Cron de archivado

```cron
0 3 * * * php /var/www/viax/backend/scripts/archive_tracking_points.php >> /var/log/viax/archive_tracking.log 2>&1
```

## Prueba de integracion recomendada

1. Crear solicitud desde app/pasajero.
2. Verificar enqueue:
- `LLEN ride_requests_queue`
3. Verificar oferta activa:
- `GET ride:{id}:current_offer`
4. Simular/realizar aceptacion en app conductor.
5. Validar:
- estado en `solicitudes_servicio`
- `GET ride:{id}:accepted_driver`
- incremento de metricas.

## Riesgos y mitigaciones

1. Doble oferta por concurrencia
- Mitigacion: lock por conductor con TTL + liberacion en aceptacion/timeout.

2. Conductores stale en GEO
- Mitigacion: refrescar ubicacion periodicamente y estado `available/on_trip/offline`.

3. Saturacion en horas pico
- Mitigacion: escalado horizontal de workers + tuning de timeout/radios por zona.

## Evolucion sugerida

1. Pasar de lista Redis a Streams con consumer groups para trazabilidad completa.
2. Persistir historico de ofertas para auditoria y entrenamiento de modelos ETA/acceptance.
3. Introducir notificaciones push transaccionales por oferta con ack explicito.

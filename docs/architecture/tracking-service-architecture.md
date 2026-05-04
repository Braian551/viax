# Tracking-service

## Stack

- Node.js 20 Alpine en Docker.
- Redis Streams como entrada y Redis Pub/Sub como salida hacia el gateway WS.
- Supervisor mantiene vivo el `docker compose`.
- Contenedor: `viax_tracking_service`.
- Ruta local: `services/tracking/`.
- Ruta produccion: `/var/www/viax/services/tracking/`.

## Flujo

`register_point.php` agrega puntos al stream `trip_tracking_stream`. El worker PHP `tracking_stream_worker.php` consume el mismo stream con el grupo `tracking_workers` y persiste los puntos en `trip_tracking_points`.

El tracking-service Node consume `trip_tracking_stream` con un grupo separado, `tracking_realtime_publishers`, y publica eventos formales en `viax:events`. El realtime-gateway escucha ese canal, normaliza el contrato y reenvia el evento a los topics WebSocket incluidos en `channels`.

Flujo completo:

```text
register_point.php
  -> trip_tracking_stream
  -> tracking-service Node
  -> viax:events
  -> realtime-gateway
  -> topics WS trip:{id} y driver:{id}
  -> cliente WS
```

## Diferencia con el worker PHP

- Worker PHP: fuente de persistencia. Lee `trip_tracking_stream`, inserta en BD y confirma con `XACK` en el grupo `tracking_workers`.
- Tracking-service Node: puente realtime. Lee el mismo stream en `tracking_realtime_publishers`, publica al gateway WS y confirma sus propios mensajes con `XACK`.

Los grupos son independientes, por eso el servicio Node no roba mensajes al worker PHP ni reemplaza la persistencia existente.

## Contrato de eventos

El gateway no consume canales especificos `viax:trip:{id}`. Consume `viax:events` y exige JSON con el contrato de `event-contract.js`.

Ejemplo:

```json
{
  "type": "trip.location_updated",
  "version": 1,
  "entity": "trip",
  "entity_id": "108",
  "timestamp": 1777824559,
  "payload": {
    "trip_id": 108,
    "driver_id": 6,
    "conductor_id": 6,
    "lat": 6.2546244571743,
    "lng": -75.539453498314,
    "speed": 0,
    "heading": 0,
    "timestamp": 1777824559,
    "precision_gps": 5,
    "distance_km": 0,
    "elapsed_time_sec": 10,
    "snap_source": "cache",
    "source": "tracking_service"
  },
  "event_id": "trip.location_updated:trip:108:1777824559",
  "channels": ["trip:108", "driver:6"]
}
```

## Monitoreo

```bash
bash scripts/check_tracking_metrics.sh
bash scripts/check_tracking_metrics.sh 2026-05-03
```

Verificaciones rapidas en produccion:

```bash
docker logs viax_tracking_service --tail 40
redis-cli XPENDING trip_tracking_stream tracking_realtime_publishers
redis-cli PUBSUB CHANNELS "viax:*"
redis-cli GET tracking:metrics:total:$(date +%Y-%m-%d)
redis-cli GET tracking:metrics:puntos_publicados:$(date +%Y-%m-%d)
redis-cli GET tracking:metrics:errores:$(date +%Y-%m-%d)
```

## Deploy

El patron es el mismo de dispatch-service y pricing-service: subir archivos con `scp`, validar sintaxis con `node --check`, construir imagen con `docker build -t viax-tracking:latest .` y levantar con `docker compose up -d`.

No se ejecuta `deploy.sh` para microservicios Node.

# Pricing-service

## Stack

- Node.js 20 Alpine en Docker.
- Redis como bus de eventos, cache operativa y metricas.
- Supervisor mantiene vivo el `docker compose`.
- Contenedor: `viax_pricing_service`.
- Ruta local: `services/pricing/`.
- Ruta produccion: `/var/www/viax/services/pricing/`.

## Flujo

El servicio escucha `pricing:quote_queue` y espera mensajes JSON con `request_id`, `distancia_km`, `duracion_minutos`, `tipo_vehiculo`, `lat_origen` y `lng_origen`. Publica el resultado en `pricing:quote_result:{request_id}` y tambien deja la misma clave en Redis con TTL corto para consultas de diagnostico.

Actualmente `backend/pricing/calculate_quote.php` y `backend/user/create_trip_request.php` delegan al pricing-service Node como fuente de verdad pre-viaje. PHP conserva fallback local si el contenedor Node no responde dentro del timeout configurado.

## Modo activo

`PRICING_SERVICE_MODE=active` indica que el servicio ya no corre solo como sombra para el flujo pre-viaje. El precio visible al usuario se resuelve en Node y PHP actua como capa de compatibilidad, validacion y fallback.

Si un evento aun incluye precio PHP (`precio_estimado`, `precio_php` o equivalente), el servicio puede seguir publicando auditoria comparativa, pero el flujo principal ya delega en Node.

## Variables

- `REDIS_HOST`: fallback `127.0.0.1`.
- `REDIS_PORT`: fallback `6379`.
- `NODE_ENV`: fallback `production`.
- `PRICING_SERVICE_MODE`: fallback `shadow`.
- `CONFIG_CACHE_TTL`: fallback `300`.

## Pricing

La calculadora replica el endpoint `backend/pricing/calculate_quote.php`: tarifa base, costo por km, costo por minuto, descuento por distancia larga, recargos por horario, tarifa minima/maxima y comision. El precio upfront se normaliza a COP en multiplos de 100, igual que `UpfrontPricingService::normalizeCopAmount`.

La grilla de zona replica `DynamicPricingService::zoneKey()` del backend PHP:

- `floor(lat * 100)`
- `floor(lng * 100)`
- formato final `zone:{latIndex}:{lngIndex}`

Ejemplo real para Medellin centro (`6.2546`, `-75.5396`): `zone:625:-7554`.

El surge se lee desde Redis con la misma clave canonica del backend PHP:

1. `surge_zone:{zone_key}`.
2. Fallback `1.0` si no existe cache de surge para la zona.

La calculadora tambien expone helpers para:

- suavizado y tabla progresiva de surge (`smoothSurge`, `resolveSurgeTarget`, `surgeScaleTable`)
- resolucion de precio upfront con proteccion de margen (`resolverPrecioFinal`)
- compensacion del conductor sobre recorrido real (`calcularCompensacionConductor`)

## Monitoreo

```bash
bash scripts/check_pricing_metrics.sh
bash scripts/check_pricing_metrics.sh 2026-05-02
```

Verificaciones rapidas en produccion:

```bash
docker logs viax_pricing_service --tail 40
redis-cli PUBSUB NUMSUB dispatch:trip_queue
curl -s -w "Health: %{http_code}" -o /dev/null http://127.0.0.1/health.php
```

## Deploy

El patron es el mismo de dispatch-service: subir archivos con `scp`, validar sintaxis con `node --check`, construir imagen con `docker build -t viax-pricing:latest .` y levantar con `docker compose up -d`.

No se ejecuta `deploy.sh` para microservicios Node.

## Rollback

Como PHP mantiene fallback local para el pricing pre-viaje, el rollback operativo sigue siendo:

```bash
cd /var/www/viax/services/pricing
docker compose down
supervisorctl stop viax_pricing_service
```

PHP continua calculando y congelando precios upfront.

## Estado de migración — 2026-05-03

- `calculate_quote.php`: delega al Node, fallback PHP si timeout >2s.
- `create_trip_request.php`: delega al Node, fallback PHP si timeout >3s.
- `finalize.php`: sigue en PHP (depende de tracking real — Fase 3).
- Código PHP de cálculo mantenido como fallback, no eliminado aún.
- Próximo paso: eliminar fallback PHP cuando el Node tenga 7 días estable.

## Proximos pasos

Fase 3: extraer tracking-service sin modificar la logica final de cobro y, cuando la ventana operativa sea estable, retirar el fallback PHP del pricing pre-viaje.

## Estado de paridad Node vs PHP

Validacion manual ejecutada el 2026-05-03 con `request_id=880002` y parametros:

- `distancia_km=5.2`
- `duracion_minutos=18`
- `tipo_vehiculo=moto`
- `lat_origen=6.2546`
- `lng_origen=-75.5396`

| Componente | Estado | Diferencia |
| --- | --- | --- |
| Tarifa base | ✅ Paridad | 0% |
| Cálculo por distancia | ✅ Paridad | 0% |
| Cálculo por tiempo | ✅ Paridad | 0% |
| Recargo horario | ✅ Paridad | 0% |
| Grilla de zona | ✅ Corregido | 0% |
| Surge desde Redis | ✅ Implementado | 0% |
| Margen protección upfront | ✅ Implementado | 0% |
| Compensación conductor | ✅ Corregido | 0% en total del usuario |

Criterio de migracion limpia alcanzado para esta prueba de shadow: diferencia total Node vs PHP de `0.00%`.

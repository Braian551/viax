# Dispatch Service - Arquitectura y Operacion

**Ultima actualizacion:** 2026-05-02  
**Estado:** Produccion - modo hybrid, dockerizado

---

## Resumen

El dispatch-service es el primer microservicio extraido del monolito PHP de Viax.
Gestiona la asignacion de conductores a viajes en tiempo real usando Redis como
transporte de eventos.

---

## Stack

| Componente | Tecnologia | Version |
|---|---|---|
| Runtime | Node.js | 20 (Alpine) |
| Contenedor | Docker | 29.4.2 |
| Orquestador local | Docker Compose | v5.1.3 |
| Supervisor de procesos | Supervisor | - |
| Transporte de eventos | Redis Pub/Sub | - |
| Canal de entrada | `dispatch:trip_queue` | - |

---

## Estructura de archivos

```text
services/dispatch/
|- src/
|  |- worker.js      <- proceso principal, punto de entrada
|  |- redis.js       <- tres conexiones separadas (subscriber/publisher/commands)
|  |- matching.js    <- logica de asignacion de conductores
|  `- config.js      <- variables de entorno con fallback
|- logs/
|  |- worker.log     <- output del proceso Node
|  |- worker.err.log <- errores del proceso Node
|  `- supervisor.log <- output de Supervisor gestionando Docker
|- Dockerfile        <- node:20-alpine, produccion
`- docker-compose.yml <- network_mode: host, container: viax_dispatch_service
```

---

## Flujo de eventos

```text
App movil (usuario)
  |
Nginx
  |
Core API PHP ---- MySQL (fuente de verdad)
  |
  +-- LPUSH   -> dispatch:trip_queue   (worker PHP legacy)
  `-- PUBLISH -> dispatch:trip_queue   (DispatchServicePublisher.php)
  |
[Docker] dispatch-service (Node)
  +-- subscriber -> escucha dispatch:trip_queue
  +-- commands   -> locks en Redis (trip:{id}:processing)
  `-- publisher  -> emite ofertas a driver:{id}:trip_offer
  |
realtime-gateway (WebSocket) -> app conductor
```

---

## Conexiones Redis

El worker usa **tres clientes Redis separados** para evitar el error
`Connection in subscriber mode`.

| Cliente | Uso | Comandos permitidos |
|---|---|---|
| `subscriber` | Escuchar eventos entrantes | SUBSCRIBE, PSUBSCRIBE |
| `publisher` | Emitir ofertas a conductores | PUBLISH |
| `commands` | Locks y auditoria de estado | GET, SET, EXPIRE, DEL |

---

## Variables de entorno

| Variable | Valor en produccion | Fallback en config.js |
|---|---|---|
| `NODE_ENV` | `production` | - |
| `REDIS_HOST` | `127.0.0.1` | `127.0.0.1` |
| `REDIS_PORT` | `6379` | `6379` |
| `DISPATCH_SERVICE_MODE` | `hybrid` | `hybrid` |

`network_mode: host` en Docker Compose permite que el contenedor acceda
a Redis en `127.0.0.1` sin exponer puertos ni modificar la configuracion de Redis.

---

## Modo hybrid

El sistema opera en modo **hybrid**: PHP y el dispatch-service coexisten.

- PHP hace `LPUSH` al canal (flujo legacy, procesado por `dispatch_worker.php`)
- PHP hace `PUBLISH` al canal (flujo nuevo, procesado por `dispatch-service`)
- El worker Node distingue ambos tipos:
  - Numero crudo -> `[DISPATCH_LEGACY]` (ignorado, procesado por PHP)
  - JSON valido -> procesado por dispatch-service
  - JSON invalido -> `[DISPATCH_WARN]` (error real)

---

## Anti-duplicacion

Locks en Redis con TTL de 15 segundos.

| Clave | TTL | Proposito |
|---|---|---|
| `trip:{id}:processing` | 15s | Bloquea procesamiento doble |
| `trip:{id}:offer_sent` | 15s | Bloquea oferta duplicada |

---

## Gestion del proceso

**Supervisor gestiona el contenedor Docker**, no el proceso Node directamente.

```bash
supervisorctl status viax_dispatch_service
supervisorctl restart viax_dispatch_service
supervisorctl stop viax_dispatch_service
```

**Docker directo** para diagnostico:

```bash
docker ps | grep viax_dispatch
docker logs viax_dispatch_service
docker logs viax_dispatch_service --tail 20
```

---

## Deploy de cambios

Si se modifica codigo en `services/dispatch/src/`:

```bash
# 1. Validar sintaxis
node --check services/dispatch/src/worker.js

# 2. Subir archivo modificado
scp services/dispatch/src/{archivo}.js root@76.13.114.194:/var/www/viax/services/dispatch/src/

# 3. Rebuild de imagen
ssh root@76.13.114.194 'cd /var/www/viax/services/dispatch && docker build -t viax-dispatch:latest .'

# 4. Reiniciar solo el servicio
ssh root@76.13.114.194 'cd /var/www/viax/services/dispatch && docker compose down && docker compose up -d'

# 5. Verificar
ssh root@76.13.114.194 'redis-cli PUBSUB NUMSUB dispatch:trip_queue && docker logs viax_dispatch_service --tail 10'
```

**NO usar `deploy.sh` para cambios en microservicios Node.**  
`deploy.sh` es exclusivo del backend PHP.

---

## Rollback a Node directo

Si Docker presenta problemas, el rollback a Node directo toma menos de 30 segundos:

```bash
bash scripts/rollback_dispatch_docker.sh
```

El script esta en `scripts/rollback_dispatch_docker.sh` (local) y en
`/var/www/viax/scripts/rollback_dispatch_docker.sh` (servidor).

---

## Monitoreo

```bash
# Subscriber activo (debe ser 1)
redis-cli PUBSUB NUMSUB dispatch:trip_queue

# Seguir logs en tiempo real
ssh root@76.13.114.194 'docker logs viax_dispatch_service -f'

# Ver DISPATCH_OFFER, sin conductor, warnings
ssh root@76.13.114.194 'docker logs viax_dispatch_service -f' | grep -E "DISPATCH_OFFER|DISPATCH_LEGACY|DISPATCH_WARN|sin conductor"

# Health general
curl -s -w "%{http_code}" -o /dev/null http://76.13.114.194/health.php
```

---

## Historial

| Fecha | Evento |
|---|---|
| 2026-03-12 | dispatch_worker.php legacy activo |
| 2026-05-01 | dispatch-service Node introducido en modo shadow |
| 2026-05-01 | Modo hybrid activado, tres conexiones Redis separadas |
| 2026-05-01 | Estructura reorganizada: `services/`, `infra/`, `docs/` |
| 2026-05-02 | Migracion a Docker, Supervisor gestiona contenedor |

---

## Proximos pasos

- [ ] Validar `DISPATCH_OFFER` real con conductor activo en WebSocket
- [ ] Fase 2: pricing-service en `services/pricing/`
- [ ] Fase 3: tracking-service en `services/tracking/`
- [ ] Metricas Redis: conteo de viajes procesados, ofertas emitidas, duplicados bloqueados
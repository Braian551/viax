# Hardening Produccion Viax (Cierre Final)

## Fecha
- 2026-03-30 (America/Bogota)
- 2026-04-01 (America/Bogota) - cierre incremental matching + CORS trip/*

## Actualizacion 2026-04-01 (cierre operativo en produccion)
- Matching progresivo real (uno a uno) reforzado:
  - `OFFER_BATCH_SIZE=1`
  - `DRIVER_OFFER_TTL_SEC=25`
  - `UI_ROTATION_SEC=5`
  - Cola canónica adicional `ride:{tripId}:drivers_queue` sin romper key legacy.
  - Estado de matching en Redis (`searching/checking/expanding_search/matched/timeout/sin_conductores`).
- UX real (no fake) confirmada en backend:
  - `driver_checking` solo se expone cuando existe `current_driver` real en Redis.
  - `matching_status` expuesto en `trip` y `meta` para frontend progresivo.
- Lógica azar/empresa fortalecida:
  - cambio de modo limpia `drivers_queue`, `current_driver` y `driver:*:status`.
  - regeneración de cola segura y marcada en `matching_status=searching`.
- Consistencia temporal:
  - pricing nocturno ajustado a ventana Colombia `21:00-05:59`.
  - worker de surge usa hora Colombia para buckets de demanda.
- CORS crítico cerrado también en endpoints `trip/*` de producción:
  - se eliminó wildcard en `trip/summary.php`, `trip/tracking_update.php`, `trip/finalize.php`.
  - allowlist estricta (`viaxcol.online` y `www.viaxcol.online`), bloqueo para origen inválido.
  - requests sin `Origin` se permiten (compatibilidad app móvil).
- Verificación de workers:
  - `viax_dispatch_worker` RUNNING
  - `viax-dispatch-worker` legacy no activo.
- Pruebas ejecutadas:
  - `backend/scripts/test_upfront_pricing_hybrid.php` -> `OK=7 FAIL=0` (local + producción)
  - `backend/scripts/test_hardening_smoke.php` -> `HARDENING_SMOKE_OK` (local + producción)
  - smokes de endpoints y `health.php=200` después de cada deploy incremental.

## Alcance
- Endurecimiento incremental y backward compatible de backend en produccion.
- Despliegue siguiendo flujo `promptbase` (sin Git en servidor).
- Validacion operativa real (E2E) con evidencia de BD y endpoints.

## Actualizacion 2026-03-31 (pricing + matching + UX)
- Se completo el flujo de busqueda progresiva estilo DiDi/Uber sin romper contratos:
  - Backend ahora refresca cola Redis de candidatos al cambiar empresa o pasar a modo azar.
  - `get_trip_status` entrega `driver_checking` y `search_mode` para feedback en tiempo real.
- Frontend de busqueda muestra estados dinamicos:
  - "`Buscando conductor...`"
  - "`<Conductor> esta revisando tu solicitud`"
  - "`<Empresa> esta evaluando tu viaje`"
- UI de viaje activo se blindó para no mutar el precio visible por tracking:
  - Se elimina fallback de precio basado en `backendPrice`/tracking en vivo.
  - Se mantiene precio visible congelado (`precio_fijo`, fallback `precio_estimado`).
  - En cierre de viaje, si tracking real no es valido, se muestran metricas estimadas y se conserva precio fijo.

## Cambios aplicados

### 0) Actualizacion final (pricing + tiempo + UI robusta)
- Se reforzo consistencia temporal en backend para pricing y logs con helper Colombia:
  - [timezone.php](/C:/Flutter/viax/backend/config/timezone.php)
  - [create_trip_request.php](/C:/Flutter/viax/backend/user/create_trip_request.php)
  - [finalize.php](/C:/Flutter/viax/backend/conductor/tracking/finalize.php)
- `get_trip_status` ahora expone campos del flujo hibrido sin romper contrato:
  - `precio_fijo`
  - `precio_congelado`
  - `precio_calculado_real`
  - `desviacion_porcentaje`
  - `tracking_valido`
  - Archivo: [get_trip_status.php](/C:/Flutter/viax/backend/user/get_trip_status.php)
- UI robusta (conductor + cliente):
  - precio visible congelado en `precio_fijo`/`precio_estimado`
  - fallback a metricas estimadas cuando `tracking_valido=false`
  - evita mostrar `0 km`/`0 min` reales en cierres sin tracking suficiente
  - Archivos:
    - [active_trip_screen.dart](/C:/Flutter/viax/lib/src/features/conductor/presentation/screens/active_trip_screen.dart)
    - [user_active_trip_screen.dart](/C:/Flutter/viax/lib/src/features/user/presentation/screens/user_active_trip_screen.dart)

### 1) CORS critico (cerrado)
- Se removio wildcard y fallback dinamico inseguro.
- Se normalizo CORS en endpoints backend a allowlist estricta:
  - `https://viaxcol.online`
  - `https://www.viaxcol.online`
- Requests sin `Origin` no se bloquean (app movil).
- Archivo central: [config.php](/C:/Flutter/viax/backend/config/config.php)
- Se normalizaron tambien endpoints legacy que tenian header CORS inline.

### 2) Bypass 8052 seguro
- Nuevo guard central: [TestBypass.php](/C:/Flutter/viax/backend/core/TestBypass.php)
- Integrado en:
  - [verify_code.php](/C:/Flutter/viax/backend/auth/verify_code.php)
  - [change_password.php](/C:/Flutter/viax/backend/auth/change_password.php)
- Regla:
  - En `production`: solo si `TEST_BYPASS_ENABLED=true`
  - En no productivo: permitido para QA
- Controles:
  - rate limit estricto
  - restriccion opcional por IP (`TEST_BYPASS_ALLOWED_IPS`)
  - log de uso estructurado `[security][test_bypass]`
- Flags documentadas en:
  - [backend/.env.example](/C:/Flutter/viax/backend/.env.example)
  - [backend/.env.security](/C:/Flutter/viax/backend/.env.security)

### 3) Worker duplicado eliminado
- Se detectaron dos programas supervisor:
  - `viax-dispatch-worker` (legacy)
  - `viax_dispatch_worker` (activo objetivo)
- Accion:
  - Se desactivo legacy moviendo `/etc/supervisor/conf.d/viax-workers.conf` a `.disabled` con backup.
  - Se hizo `reread/update` y se verifico que solo quedara `viax_dispatch_worker`.
- Resultado:
  - Unico proceso de dispatch en runtime.

### 4) Rate limiter hotfix
- Se endurecio [RateLimiter.php](/C:/Flutter/viax/backend/core/RateLimiter.php):
  - fallback local en memoria cuando Redis no esta disponible
  - logging controlado de degradacion (`[security][rate_limiter]`)
  - evita bypass total por caida de Redis
- Workers reiniciados para cargar cambios.

### 5) Pricing hibrido y finalize
- Se corrigio `finalize` para manejar `Throwable` y evitar 500 sin cuerpo.
- Se corrigio include faltante de `DynamicPricingService` en:
  - [finalize.php](/C:/Flutter/viax/backend/conductor/tracking/finalize.php)
  - usando `services/pricing_service.php`.

### 6) Feature flags
- Alias central agregado:
  - `Feature::isEnabled(...)` en [Feature.php](/C:/Flutter/viax/backend/core/Feature.php)
- Flag mapeado:
  - `test_bypass` -> `TEST_BYPASS_ENABLED`

### 7) Testing automatizado
- Script actualizado: [test_upfront_pricing_hybrid.php](/C:/Flutter/viax/backend/scripts/test_upfront_pricing_hybrid.php)
- Casos incluidos:
  1. flujo normal
  2. usuario no se mueve (tracking invalido)
  3. desviacion > 30%
  4. tarifa nocturna (hora Colombia)
  5. cambio destino
  6. fraude ruta ineficiente
  7. 8052 solo con flag activo
- Resultado local actual:
  - `OK=7 FAIL=0`

## Evidencia operativa (produccion)

### Despliegue
- `check_pending_migrations.php` -> `NO_PENDING_MIGRATIONS`
- `deploy.sh` ejecutado correctamente
- Smoke endpoints:
  - `POST /user/create_trip_request.php` -> `400` (validacion esperada)
  - `POST /conductor/update_trip_status.php` -> `400` (validacion esperada)
  - `POST /user/trip_preview.php` -> `400` (validacion esperada)
- `GET /health.php` -> `200`
- `redis-cli ping` -> `PONG`

### CORS verificado
- Origin permitido (`https://viaxcol.online`) -> retorna `Access-Control-Allow-Origin` correcto.
- Origin invalido -> no expone ACAO permitido.
- Sin Origin -> no bloqueo.
- Sin `Access-Control-Allow-Origin: *`.

### E2E real (viaje de prueba `solicitud_id=25`)
- Flujo ejecutado:
  1. crear viaje
  2. aceptar conductor
  3. tracking lote de 5 puntos
  4. finalizar tracking
- Respuesta finalize: `HTTP 200`.
- Evidencia BD (`solicitudes_servicio`):
  - `precio_estimado=16053.33`
  - `precio_fijo=16053.33`
  - `precio_calculado_real=15500.00`
  - `precio_final=16053.33`
  - `precio_congelado=true`
- Evidencia BD (`viaje_resumen_tracking`):
  - `precio_final_calculado=15500.00`
  - `precio_final_aplicado=16053.33`
  - `ganancia_conductor=7112.00`
- Validacion clave:
  - `precio_final != pago_conductor` (correcto para modelo hibrido)

### Estados de usuario
- Consulta ejecutada:
  - `SELECT DISTINCT status FROM usuarios ORDER BY status;`
- Resultado:
  - `active`
  - `inactive`
- No se detectaron estados fuera del dominio permitido.

## Estado final
- Backend estable.
- Sin regresiones criticas detectadas en smoke + E2E real.
- Flujo hibrido validado en produccion.
- Seguridad/CORS/endurecimiento listos para escala incremental.

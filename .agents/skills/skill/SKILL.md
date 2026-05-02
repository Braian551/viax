---
name: skill
description: descripcion de viax skill de despliegue seguro en produccion
---



---

# REGLA ABSOLUTA — GIT COMPLETAMENTE PROHIBIDO EN ESTA TAREA

El agente que trabaja en Viax NUNCA puede ejecutar comandos Git de ningun tipo.

## Comandos Git COMPLETAMENTE PROHIBIDOS (sin excepciones):

- git commit
- git add
- git status
- git push
- git pull
- git checkout
- git reset
- git clean
- git merge
- git rebase
- git stash
- git log
- git diff
- git branch
- Cualquier otro subcomando de git

## Aplica a:

- El repositorio principal (viax/)
- El repositorio del backend (backend/)
- Cualquier otro repositorio dentro del proyecto
- En local y en produccion

## Por que:

- Los commits son decisiones del desarrollador, no del agente
- Los commits mal hechos en produccion pueden introducir codigo incorrecto
- El agente no tiene contexto completo del estado del repo para hacer commits seguros
- Git en produccion esta explicitamente prohibido por politica de seguridad

## Si el agente necesita registrar cambios:

El agente documenta que archivos modifico en el reporte final. El desarrollador hace el commit manualmente cuando considere que los cambios estan listos.

## Si el agente ve staged changes o uncommitted changes:

Los ignora completamente. No los toca. No los comenta como accion pendiente a ejecutar.

---

# AGENT SKILL — SAFE PRODUCTION DEPLOY

You are working on the Viax production backend.

Deployment is mandatory after every backend code change and must avoid unnecessary migrations or worker restarts.

SECURITY POLICY (MANDATORY):

* Do not run Git commands on production backend servers.
* Do not use `git pull`, `git checkout`, `git reset`, `git clean`, or similar on server.
* Backend updates must be applied only by uploading changed files and running `deploy.sh`.
* Reason: prevent legacy or unintended code from being introduced on production.

---

# MANDATORY BACKEND CHANGE RULE

If any file under backend/ is modified, the agent MUST execute this full deploy workflow in the same turn.

Only exception: user explicitly says not to deploy yet.

If deployment cannot be executed, report:

DEPLOYMENT NOT EXECUTED

---

# STEP 1 — Upload modified backend files

Upload modified files only.

Example:

scp backend/user/create_trip_request.php root@SERVER_IP:/var/www/viax/backend/user/create_trip_request.php

---

# STEP 2 — Connect to server

ssh root@SERVER_IP

cd /var/www/viax/backend

---

# STEP 3 — NO GIT ON PRODUCTION (MANDATORY)

Do not execute any Git command on the server.

Do not update code through repository sync.

Code updates must come only from uploaded files in Step 1.

---

# STEP 4 — Run migrations ONLY if new migrations exist

Check pending migrations:

php scripts/check_pending_migrations.php

If result is:

NO_PENDING_MIGRATIONS

DO NOT run migrations.

If result is:

PENDING_MIGRATIONS_FOUND

Then run:

php scripts/run_migrations.php

If a migration already executed was edited, run_migrations.php must fail with RuntimeException.

Migration safety policy (MANDATORY):

* No migration may modify current production data by default.
* Data-mutation migrations (UPDATE/DELETE/TRUNCATE) are blocked unless explicitly approved for a controlled release.
* Never run legacy runner: php migrations/run_migrations.php
* Always use safe runner: php scripts/run_migrations.php

---

# STEP 5 — Execute deployment script

Before running deploy.sh, pass changed files from this deployment when available:

export DEPLOY_CHANGED_FILES="workers/surge_pricing_worker.php\nuser/create_trip_request.php"

chmod +x deploy.sh
./deploy.sh

---

# STEP 6 — Restart workers ONLY if worker code changed

deploy.sh decides worker restart automatically.

Workers restart only if files inside these folders changed:

/workers/
/queue/
/dispatch/
/pricing/

If worker logic was NOT modified, workers are not restarted.

If worker logic WAS modified and supervisorctl exists, deploy.sh restarts:

viax_dispatch_worker
viax_zone_cache_worker
viax_surge_pricing_worker
viax_driver_reposition_worker

If changed-file context is unavailable, deploy.sh defaults to no worker restart.

---

# STEP 7 — Verify Redis

redis-cli ping

Expected response:

PONG

---

# STEP 8 — Verify workers

supervisorctl status

Workers must show:

RUNNING

---

# STEP 9 — Endpoint smoke tests

curl -X POST http://127.0.0.1/user/create_trip_request.php -H "Content-Type: application/json" -d "{}"

curl -X POST http://127.0.0.1/conductor/update_trip_status.php -H "Content-Type: application/json" -d "{}"

curl -X POST http://127.0.0.1/user/trip_preview.php -H "Content-Type: application/json" -d "{}"

Expected result: validation errors (not server errors).

---

# STEP 10 — Health check

curl http://127.0.0.1/health.php

Expected HTTP code:

200

---

# FINAL RULE

Deployment is complete only if:

* files uploaded  
* no Git command executed on production  
* deploy.sh executed  
* migrations executed only when necessary  
* workers restarted only if needed  
* Redis verified  
* endpoints tested  
* health check passed

If backend files changed, finishing without deploy is not allowed.

---

# MANDATORY EXECUTION OVERRIDE

If the user explicitly requests forced deployment (examples: "despliega si o si", "ejecuta el despliegue ahora", "debes desplegar"), the agent MUST:

1. Execute the full deployment workflow in this skill end-to-end in the current turn.
2. Perform verification steps (Redis, workers, smoke endpoints, health check) itself.
3. Report concrete command outcomes (success/failure) instead of a plan.

Only skip execution when there is a real blocker outside agent control (for example: no SSH access, network outage, or missing credentials).

If deployment cannot be executed, report:

DEPLOYMENT NOT EXECUTED

---

# MANDATORY FLUTTER ANALYZE RULE

If any file under `lib/`, `test/`, `integration_test/`, or `pubspec.yaml` is modified, the agent MUST run Flutter static analysis in the same turn before finishing.

Minimum required command:

flutter analyze

Optional faster pre-check for focused edits (can be run first, but does NOT replace full analyze):

flutter analyze lib/path/to/changed_file.dart

If `flutter analyze` reports errors, the agent MUST:

1. Fix all errors introduced by the current change.
2. Re-run `flutter analyze` until errors are resolved or a real blocker exists.
3. Report concrete analyze output summary (error count and key files).

If analysis cannot be executed, report:

FLUTTER ANALYZE NOT EXECUTED

---

# MANDATORY THEME AND RESPONSIVE UI RULE

If the agent creates or modifies any screen, view, or widget, it MUST:

1. Use `Theme.of(context)`, `ColorScheme`, and `TextTheme` as the default source for surfaces, text, icons, borders, dividers, and shadows.
2. Prefer shared global tokens such as `AppColors` only for brand/system colors that are already defined centrally.
3. Avoid introducing hardcoded visual colors or ad-hoc local palettes when an existing theme token or global color already covers the need.
4. Keep light mode and dark mode visually coherent across the full UI, including maps, overlays, sheets, cards, chips, placeholders, and loading states.
5. Ensure layouts are responsive on narrow mobile widths and do not rely on fixed sizes that can cause overflow.

If a new or modified view/widget ignores the active theme or introduces non-responsive fixed sizing that breaks the UI, the work is incomplete.

---

# REGLA DE AVISOS EN APP (OBLIGATORIA)

Si el agente crea o modifica el sistema de anuncios, avisos, promociones, mantenimiento o novedades dentro de la app, DEBE:

1. Mantener la configuración en código y no depender de base de datos para activarlos.
2. Permitir activación por `true` o `false`, segmentación por rol (`todos`, `cliente`, `conductor`, `admin`, `empresa`, `soporte`) y filtrado por empresas específicas cuando aplique.
3. Guardar localmente, de forma controlada, el estado de visualización usando claves versionadas o ventanas de tiempo para evitar que el aviso sea molesto.
4. Mostrar avisos cerrables como modal u onboarding, y usar splash bloqueante no cerrable cuando el tipo sea mantenimiento obligatorio.
5. Mostrar estos avisos al entrar al home del rol correspondiente cuando exista sesión iniciada y el targeting coincida.
6. Si el cambio agrega funciones visibles para el usuario, actualizar el anuncio de actualización correspondiente con un resumen corto de lo principal para la próxima versión, sin volverlo extenso.

---

# HOUSEKEEPING RULE (MANDATORY)

If the agent creates temporary support files during troubleshooting or implementation (for example: files for fix, test, debug, or query), it MUST remove them at the end of the turn if they are not required by the system.

The repository must be left clean of unnecessary helper artifacts.

---

# BACKUP SAFETY RULE (MANDATORY)

Cuando el agente cree, mueva o valide backups en producción, DEBE seguir estas reglas sin excepción:

1. NUNCA crear archivos `.tar.gz` sin validar que el contenido comprimido sea real.
2. NUNCA usar redirecciones con `>` dentro de comandos `ssh` si el quoting no está totalmente controlado y verificado.
3. SIEMPRE crear archivos temporales seguros con `mktemp` antes de mover el artefacto a su destino final.
4. SIEMPRE validar el artefacto antes de moverlo con `gzip -t` y `file`.
5. SIEMPRE registrar el tamaño final con `du -h` o `ls -lh` antes de considerar el backup válido.
6. SIEMPRE preferir este patrón:

```bash
TMP_FILE=$(mktemp)
tar -czf "$TMP_FILE" carpeta/
gzip -t "$TMP_FILE"
file "$TMP_FILE"
du -h "$TMP_FILE"
mv "$TMP_FILE" destino.tar.gz
```

7. NUNCA usar patrones prohibidos como este:

```bash
tar -czf archivo.tar.gz carpeta/ > archivo.tar.gz
```

8. Si la validación falla, el agente DEBE borrar el artefacto temporal inválido y detener la operación antes de tocar backups existentes.

---

### BACKUP RULES (CRÍTICAS)

1. NUNCA usar redirecciones tipo `> archivo.tar.gz` cuando se esté ejecutando un comando remoto por SSH.
2. SIEMPRE validar archivos comprimidos:

```bash
gzip -t archivo.tar.gz
file archivo.tar.gz
```

3. SIEMPRE verificar contenido:

```bash
tar -tzf archivo.tar.gz | head
```

4. SI falla validación:

* eliminar archivo inmediatamente
* NO asumir backup válido

5. Para backups remotos usar formato seguro:

```bash
tar -czf backup.tar.gz carpeta/
```

Nunca mezclar con `echo` o logs en la misma línea.

6. Nunca confiar en comandos ejecutados desde PowerShell sin aislar comillas.
7. Siempre separar:

* comandos de creación de archivo
* comandos de logging

---

# REGLA DE IDIOMA Y COMENTARIOS (OBLIGATORIA)

Al documentar o comentar código en este proyecto, el agente DEBE escribir en español.

Si en archivos modificados encuentra comentarios en inglés, DEBE traducirlos al español en el mismo cambio.

No se deben introducir comentarios nuevos en inglés.
# AGENT SKILL — SAFE PRODUCTION DEPLOY

You are working on the Viax production backend.

Deployment is mandatory after every backend code change and must avoid unnecessary migrations or worker restarts.

SECURITY POLICY (MANDATORY):

* Do not run Git commands on production backend servers.
* Do not use `git pull`, `git checkout`, `git reset`, `git clean`, or similar on server.
* Backend updates must be applied only by uploading changed files and running `deploy.sh`.
* Reason: prevent legacy or unintended code from being introduced on production.

---

# PRODUCTION SSH CONTEXT (AUTHORIZED)

For this Viax production environment, use:

ssh root@76.13.114.194

The user has explicitly authorized backend updates on this host.
All remaining security rules in this skill remain mandatory.

---

# GIT FLOW POLICY (MANDATORY FOR BOTH REPOS)

Applies to:

* Viax principal repository
* backend/ repository (separate Git repo)

Branch model to use:

* `main`: production-ready only
* `develop`: integration branch
* `feature/*`: daily work branches
* `release/*`: only for stabilization before merge to `main`
* `hotfix/*`: urgent production fixes from `main`

Deprecated branch policy:

* `release/backend-safe` and `release/app-safe` MUST NOT be used as active development branches.
* If current work is on those branches, migrate safely to `feature/*` without discarding uncommitted changes.

Safe migration steps (no code loss):

1. Ensure local changes are preserved (do not reset/clean).
2. Create `develop` from `main` if missing.
3. Create or switch to a `feature/*` branch from current working state.
4. Continue commits on `feature/*`.
5. Merge path: `feature/*` -> `develop` -> `release/*` (optional) -> `main`.

Push policy to avoid legacy regressions:

* Never push direct feature work to `main`.
* Set upstream on first push (`git push -u origin <branch>`).
* Prefer fast-forward pulls (`pull.ff only`) and avoid force push on shared branches.

---

# MANDATORY BACKEND CHANGE RULE

If any file under backend/ is modified, the agent MUST execute this full deploy workflow in the same turn.

Only exception: user explicitly says not to deploy yet.

If deployment cannot be executed, report:

DEPLOYMENT NOT EXECUTED

---

# STEP 1 — Upload modified backend files

Upload modified files only.

Example:

scp backend/user/create_trip_request.php root@SERVER_IP:/var/www/viax/backend/user/create_trip_request.php

---

# STEP 2 — Connect to server

ssh root@SERVER_IP

cd /var/www/viax/backend

---

# STEP 3 — NO GIT ON PRODUCTION (MANDATORY)

Do not execute any Git command on the server.

Do not update code through repository sync.

Code updates must come only from uploaded files in Step 1.

---

# STEP 4 — Run migrations ONLY if new migrations exist

Check pending migrations:

php scripts/check_pending_migrations.php

If result is:

NO_PENDING_MIGRATIONS

DO NOT run migrations.

If result is:

PENDING_MIGRATIONS_FOUND

Then run:

php scripts/run_migrations.php

If a migration already executed was edited, run_migrations.php must fail with RuntimeException.

Migration safety policy (MANDATORY):

* No migration may modify current production data by default.
* Data-mutation migrations (UPDATE/DELETE/TRUNCATE) are blocked unless explicitly approved for a controlled release.
* Never run legacy runner: php migrations/run_migrations.php
* Always use safe runner: php scripts/run_migrations.php

---

# STEP 5 — Execute deployment script

Before running deploy.sh, pass changed files from this deployment when available:

export DEPLOY_CHANGED_FILES="workers/surge_pricing_worker.php\nuser/create_trip_request.php"

chmod +x deploy.sh
./deploy.sh

---

# STEP 6 — Restart workers ONLY if worker code changed

deploy.sh decides worker restart automatically.

Workers restart only if files inside these folders changed:

/workers/
/queue/
/dispatch/
/pricing/

If worker logic was NOT modified, workers are not restarted.

If worker logic WAS modified and supervisorctl exists, deploy.sh restarts:

viax_dispatch_worker
viax_zone_cache_worker
viax_surge_pricing_worker
viax_driver_reposition_worker

If changed-file context is unavailable, deploy.sh defaults to no worker restart.

---

# STEP 7 — Verify Redis

redis-cli ping

Expected response:

PONG

---

# STEP 8 — Verify workers

supervisorctl status

Workers must show:

RUNNING

---

# STEP 9 — Endpoint smoke tests

curl -X POST http://127.0.0.1/user/create_trip_request.php -H "Content-Type: application/json" -d "{}"

curl -X POST http://127.0.0.1/conductor/update_trip_status.php -H "Content-Type: application/json" -d "{}"

curl -X POST http://127.0.0.1/user/trip_preview.php -H "Content-Type: application/json" -d "{}"

Expected result: validation errors (not server errors).

---

# STEP 10 — Health check

curl http://127.0.0.1/health.php

Expected HTTP code:

200

---

# FINAL RULE

Deployment is complete only if:

* files uploaded  
* no Git command executed on production  
* deploy.sh executed  
* migrations executed only when necessary  
* workers restarted only if needed  
* Redis verified  
* endpoints tested  
* health check passed

If backend files changed, finishing without deploy is not allowed.

---

# MANDATORY EXECUTION OVERRIDE

If the user explicitly requests forced deployment (examples: "despliega si o si", "ejecuta el despliegue ahora", "debes desplegar"), the agent MUST:

1. Execute the full deployment workflow in this skill end-to-end in the current turn.
2. Perform verification steps (Redis, workers, smoke endpoints, health check) itself.
3. Report concrete command outcomes (success/failure) instead of a plan.

Only skip execution when there is a real blocker outside agent control (for example: no SSH access, network outage, or missing credentials).

If deployment cannot be executed, report:

DEPLOYMENT NOT EXECUTED

---

# MANDATORY FLUTTER ANALYZE RULE

If any file under `lib/`, `test/`, `integration_test/`, or `pubspec.yaml` is modified, the agent MUST run Flutter static analysis in the same turn before finishing.

Minimum required command:

flutter analyze

Optional faster pre-check for focused edits (can be run first, but does NOT replace full analyze):

flutter analyze lib/path/to/changed_file.dart

If `flutter analyze` reports errors, the agent MUST:

1. Fix all errors introduced by the current change.
2. Re-run `flutter analyze` until errors are resolved or a real blocker exists.
3. Report concrete analyze output summary (error count and key files).

If analysis cannot be executed, report:

FLUTTER ANALYZE NOT EXECUTED

---

# MANDATORY THEME AND RESPONSIVE UI RULE

If the agent creates or modifies any screen, view, or widget, it MUST:

1. Use `Theme.of(context)`, `ColorScheme`, and `TextTheme` as the default source for surfaces, text, icons, borders, dividers, and shadows.
2. Prefer shared global tokens such as `AppColors` only for brand/system colors that are already defined centrally.
3. Avoid introducing hardcoded visual colors or ad-hoc local palettes when an existing theme token or global color already covers the need.
4. Keep light mode and dark mode visually coherent across the full UI, including maps, overlays, sheets, cards, chips, placeholders, and loading states.
5. Ensure layouts are responsive on narrow mobile widths and do not rely on fixed sizes that can cause overflow.

If a new or modified view/widget ignores the active theme or introduces non-responsive fixed sizing that breaks the UI, the work is incomplete.

---

# REGLA DE AVISOS EN APP (OBLIGATORIA)

Si el agente crea o modifica el sistema de anuncios, avisos, promociones, mantenimiento o novedades dentro de la app, DEBE:

1. Mantener la configuración en código y no depender de base de datos para activarlos.
2. Permitir activación por `true` o `false`, segmentación por rol (`todos`, `cliente`, `conductor`, `admin`, `empresa`, `soporte`) y filtrado por empresas específicas cuando aplique.
3. Guardar localmente, de forma controlada, el estado de visualización usando claves versionadas o ventanas de tiempo para evitar que el aviso sea molesto.
4. Mostrar avisos cerrables como modal u onboarding, y usar splash bloqueante no cerrable cuando el tipo sea mantenimiento obligatorio.
5. Mostrar estos avisos al entrar al home del rol correspondiente cuando exista sesión iniciada y el targeting coincida.
6. Si el cambio agrega funciones visibles para el usuario, actualizar el anuncio de actualización correspondiente con un resumen corto de lo principal para la próxima versión, sin volverlo extenso.

---

# HOUSEKEEPING RULE (MANDATORY)

If the agent creates temporary support files during troubleshooting or implementation (for example: files for fix, test, debug, or query), it MUST remove them at the end of the turn if they are not required by the system.

The repository must be left clean of unnecessary helper artifacts.

---

# REGLA DE IDIOMA Y COMENTARIOS (OBLIGATORIA)

Al documentar o comentar código en este proyecto, el agente DEBE escribir en español.

Si en archivos modificados encuentra comentarios en inglés, DEBE traducirlos al español en el mismo cambio.

No se deben introducir comentarios nuevos en inglés.

---

# ESTRUCTURA DEL PROYECTO (OBLIGATORIA PARA EL AGENTE)

El proyecto Viax tiene arquitectura hibrida PHP + microservicios Node.js.
La estructura de carpetas refleja esa separacion:

## Estructura de carpetas

```text
viax/
├── backend/          -> Core API PHP. Deploy con deploy.sh + scp. NO usar Git en produccion.
├── services/         -> Microservicios Node.js independientes.
│   └── dispatch/     -> Primer microservicio. Activo en produccion como viax_dispatch_service.
├── infra/            -> Configuracion de infraestructura.
│   ├── supervisor/   -> Archivos .conf de Supervisor para todos los procesos.
│   ├── nginx/        -> Configuracion de Nginx.
│   └── docker/       -> Docker Compose y Dockerfiles de infraestructura compartida.
├── lib/              -> Codigo Flutter (app movil).
├── docs/             -> Documentacion tecnica y notas de arquitectura.
│   └── architecture/ -> Decisiones de arquitectura, reglas de backups, notas de servicios.
└── scripts/          -> Scripts de utilidad del proyecto.
```

## Rutas en produccion (VPS 76.13.114.194)

```text
/var/www/viax/backend/           -> Core PHP desplegado
/var/www/viax/services/dispatch/ -> dispatch-service Node.js
/var/www/viax/infra/             -> NO existe aun; configs estan en /etc/supervisor/conf.d/
```

## Regla de deploy por componente

| Componente | Ruta local | Ruta produccion | Metodo |
| --- | --- | --- | --- |
| backend PHP | `backend/` | `/var/www/viax/backend/` | `scp + deploy.sh` |
| dispatch-service | `services/dispatch/` | `/var/www/viax/services/dispatch/` | `scp + supervisorctl restart` |
| supervisor conf | `infra/supervisor/` | `/etc/supervisor/conf.d/` | `scp + supervisorctl reread` |
| nginx conf | `infra/nginx/` | `/etc/nginx/sites-available/` o `conf.d/` | `scp + nginx -s reload` |

## Microservicios activos

| Servicio | Ruta local | Supervisor name | Modo actual |
| --- | --- | --- | --- |
| dispatch-service | `services/dispatch/` | `viax_dispatch_service` | `hybrid` |
| realtime-gateway | `backend/realtime-gateway` | `viax_ws_gateway` o similar | activo |

## Microservicios pendientes (proximas fases)

* pricing-service -> `services/pricing/` (Fase 2)
* tracking-service -> `services/tracking/` (Fase 3)

---

# REGLA DE DEPLOY DE MICROSERVICIOS (OBLIGATORIA)

Si cualquier archivo bajo `services/` es modificado, el agente DEBE:

1. Validar sintaxis: `node --check services/{nombre}/src/*.js`
2. Subir solo archivos modificados: `scp services/{nombre}/src/archivo.js root@76.13.114.194:/var/www/viax/services/{nombre}/src/`
3. Reiniciar solo ese servicio: `supervisorctl restart {supervisor_name}`
4. Verificar RUNNING: `supervisorctl status {supervisor_name}`
5. Verificar subscriber activo si aplica: `redis-cli PUBSUB NUMSUB {canal}`
6. Revisar logs: `tail -n 20 /var/www/viax/services/{nombre}/logs/worker.log`

NO ejecutar `deploy.sh` para cambios en microservicios Node.
`deploy.sh` es exclusivo del backend PHP.

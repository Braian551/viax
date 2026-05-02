---
name: promptbase
description: Flujo obligatorio de despliegue seguro para produccion de Viax con validaciones operativas y sincronizacion legal. Usar cuando se modifique `backend/`, se solicite despliegue, se toquen workers o migraciones, se cambie Flutter en `lib/`, `test/`, `integration_test/` o `pubspec.yaml`, o se actualicen terminos y condiciones, politicas, consentimiento legal o `legal_content` (actualizando tambien documentacion en `docs/`).
---

# AGENT SKILL - SAFE PRODUCTION DEPLOY (VIAX)

Aplicar esta skill en cambios de backend, despliegues productivos o actualizaciones legales en Viax.

## POLITICA DE SEGURIDAD (OBLIGATORIA)

- No ejecutar comandos Git en servidores de produccion.
- No usar `git pull`, `git checkout`, `git reset`, `git clean` ni comandos equivalentes en servidor.
- Actualizar backend solo subiendo archivos modificados y ejecutando `deploy.sh`.
- Mantener comentarios y explicaciones tecnicas del proyecto en espanol.

## REGLA OBLIGATORIA DE CAMBIO BACKEND

Si se modifica cualquier archivo bajo `backend/`, ejecutar el flujo completo de despliegue en el mismo turno.

Unica excepcion: el usuario indica explicitamente que no se despliegue todavia.

Si el despliegue no puede ejecutarse, reportar exactamente:

`DEPLOYMENT NOT EXECUTED`

## PASO 1 - Subir archivos backend modificados

Subir solo los archivos cambiados.

```bash
scp backend/user/create_trip_request.php root@SERVER_IP:/var/www/viax/backend/user/create_trip_request.php
```

## PASO 2 - Conectarse al servidor

```bash
ssh root@SERVER_IP
cd /var/www/viax/backend
```

## PASO 3 - NO GIT EN PRODUCCION (OBLIGATORIO)

- No ejecutar comandos Git en el servidor.
- No sincronizar codigo con repositorio.
- Aceptar cambios solo por archivos subidos en el paso 1.

## PASO 4 - Ejecutar migraciones solo si hay pendientes

Verificar pendientes:

```bash
php scripts/check_pending_migrations.php
```

Si devuelve `NO_PENDING_MIGRATIONS`, no ejecutar migraciones.

Si devuelve `PENDING_MIGRATIONS_FOUND`, ejecutar:

```bash
php scripts/run_migrations.php
```

Politica de migraciones (obligatoria):

- No usar `php migrations/run_migrations.php`.
- No permitir por defecto migraciones que muten datos productivos.
- Bloquear `UPDATE`, `DELETE` y `TRUNCATE` salvo aprobacion explicita para release controlado.
- Si se edita una migracion ya ejecutada, `run_migrations.php` debe fallar.

## PASO 5 - Ejecutar script de deploy

Antes de `deploy.sh`, pasar archivos cambiados cuando exista ese contexto:

```bash
export DEPLOY_CHANGED_FILES="workers/surge_pricing_worker.php\nuser/create_trip_request.php"
chmod +x deploy.sh
./deploy.sh
```

## PASO 6 - Reiniciar workers solo si cambio codigo worker

`deploy.sh` decide el reinicio automaticamente.

Reiniciar solo si hubo cambios en:

- `/workers/`
- `/queue/`
- `/dispatch/`
- `/pricing/`

Si cambio logica worker y `supervisorctl` existe, esperar reinicio de:

- `viax_dispatch_worker`
- `viax_zone_cache_worker`
- `viax_surge_pricing_worker`
- `viax_driver_reposition_worker`

Si no existe contexto de archivos cambiados, `deploy.sh` asume sin reinicio.

## PASO 7 - Verificar Redis

```bash
redis-cli ping
```

Respuesta esperada: `PONG`.

## PASO 8 - Verificar workers

```bash
supervisorctl status
```

Estado esperado: `RUNNING`.

## PASO 9 - Smoke tests de endpoints

```bash
curl -X POST http://127.0.0.1/user/create_trip_request.php -H "Content-Type: application/json" -d "{}"
curl -X POST http://127.0.0.1/conductor/update_trip_status.php -H "Content-Type: application/json" -d "{}"
curl -X POST http://127.0.0.1/user/trip_preview.php -H "Content-Type: application/json" -d "{}"
```

Resultado esperado: errores de validacion, no errores de servidor.

## PASO 10 - Health check

```bash
curl http://127.0.0.1/health.php
```

Codigo esperado: `200`.

## REGLA OBLIGATORIA DE SINCRONIZACION LEGAL

Si se actualizan terminos y condiciones, politicas, consentimiento legal, versionado legal o archivos bajo:

- `assets/legal/`
- `backend/legal/`
- `lib/src/features/legal/`
- `lib/src/global/services/legal/`

entonces en el mismo turno se debe actualizar tambien:

1. `legal_content` de app, especialmente `assets/legal/legal_content.json`.
2. Versionado y endpoints legales backend que correspondan, por ejemplo `backend/legal/current_version.php` y `backend/legal/accept.php`.
3. Documentacion funcional o tecnica relacionada en `docs/` para trazabilidad del cambio legal.

No dejar cambios legales solo en frontend ni solo en backend. Mantener consistencia entre contenido legal, versionado, aceptacion y documentacion.

## REGLA FINAL

El despliegue solo se considera completo si:

- Se subieron archivos.
- No se ejecuto Git en produccion.
- Se ejecuto `deploy.sh`.
- Migraciones se ejecutaron solo si hacia falta.
- Workers se reiniciaron solo si correspondia.
- Redis fue verificado.
- Endpoints smoke fueron verificados.
- Health check paso.

Si hubo cambio en `backend/`, no se puede cerrar el turno sin desplegar o sin reportar `DEPLOYMENT NOT EXECUTED`.

## OVERRIDE DE EJECUCION OBLIGATORIA

Si el usuario pide despliegue forzado (por ejemplo: `despliega si o si`, `ejecuta el despliegue ahora`, `debes desplegar`), ejecutar el flujo completo en el mismo turno y reportar resultados concretos por comando.

Solo omitir ejecucion si existe bloqueo real fuera de control del agente (por ejemplo: falta SSH, credenciales o caida de red).

Si no puede ejecutarse, reportar exactamente:

`DEPLOYMENT NOT EXECUTED`

## REGLA OBLIGATORIA DE FLUTTER ANALYZE

Si se modifica cualquier archivo bajo `lib/`, `test/`, `integration_test/` o `pubspec.yaml`, ejecutar `flutter analyze` en el mismo turno antes de finalizar.

Puede correrse un pre-check focalizado, pero no reemplaza el analisis completo:

```bash
flutter analyze lib/path/to/changed_file.dart
flutter analyze
```

Si `flutter analyze` reporta errores:

1. Corregir todos los errores introducidos por el cambio actual.
2. Repetir `flutter analyze` hasta resolverlos o detectar un bloqueo real.
3. Reportar resumen concreto con cantidad de errores y archivos clave.

Si no puede ejecutarse, reportar exactamente:

`FLUTTER ANALYZE NOT EXECUTED`

## REGLA DE HOUSEKEEPING (OBLIGATORIA)

Eliminar archivos temporales de soporte (debug, pruebas, consultas o fixes) que no sean necesarios para el sistema final.

No dejar artefactos innecesarios en el repositorio.

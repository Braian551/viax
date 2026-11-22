# Operación de VIAX en producción

El dominio canónico es [viaxcol.online](https://viaxcol.online). El VPS es
`168.231.71.225`. HTTP y el subdominio `www` redirigen al dominio canónico.
La API de Flutter y Web vive bajo `https://viaxcol.online/api`. El gateway
recibe conexiones en `wss://viaxcol.online/ws`.

## Recursos y versiones

| Recurso | Ubicación o unidad |
| --- | --- |
| React | `/srv/viax/web/current` apunta a `releases/dd8554e` |
| PHP | `/srv/viax/backend/current` apunta a `releases/156a6eb` |
| Nginx | `/etc/nginx/sites-available/viaxcol.online.conf` |
| PHP-FPM | `viax-php.service` y `/run/viax-php/backend.sock` |
| PostgreSQL | Base `viax`, rol de ejecución `viax_app`, clúster local PostgreSQL 16 |
| Redis | `viax-redis.service`, puerto `127.0.0.1:16379`, persistencia en `/srv/viax/shared/redis` |
| WebSocket | `viax-realtime.service`, puerto interno `127.0.0.1:19100` |
| Workers | `viax-worker@dispatch`, `@surge_pricing`, `@tracking_stream`, `@zone_cache` y `@driver_reposition` |
| Certificados | `viax-cert-renew.timer`, webroot `/srv/viax/shared/acme` |
| Configuración, datos y logs | `/srv/viax/shared/{config,storage,uploads,logs}` |

Dispatch, cotización y tracking usan PHP. Node ejecuta el gateway WebSocket.
Los Compose experimentales de `services/` no forman parte de producción.
El worker de eliminación de cuentas permanece deshabilitado mientras se
revisa una solicitud histórica vencida.

`/srv/viax/deployment/public-endpoints.txt` enumera los scripts publicados.
Nginx resuelve solo las rutas de `public-api.map` en el release activo. Los
paneles React cargan, pero las operaciones heredadas que aún requieren
autorización a nivel de sesión, rol y recurso están fuera de esa lista. El
proxy R2 anónimo sirve fotos de perfil, fotos de vehículos y logos de empresa.
Los archivos privados requieren un flujo de descarga autenticado.

## Publicar por SSH

1. Confirmar el commit que se va a publicar y guardar su SHA y digest.
   Para Web, compilar con Node 22, `npm ci` y `npm run build`. Definir
   `VITE_API_URL=/api` y cargar solo configuración pública de Firebase.
   GitHub Actions compila. La publicación al VPS se hace por SCP.
2. Subir el contenido de `dist` a un archivo en `/srv/viax/deployment` y
   extraerlo en `/srv/viax/web/releases/<sha>`. Probar que incluya
   `index.html`, activos, sitemap y robots. Conservar el destino actual.
3. Exportar el Backend desde Git y excluir `vendor` y configuración local.
   Descomprimirlo en `/srv/viax/backend/releases/<sha>`. Ejecutar
   `composer install --no-dev --prefer-dist --no-interaction --no-scripts --no-plugins --optimize-autoloader`,
   `composer check-platform-reqs --no-dev` y `composer audit --locked --no-dev`.
   Para el gateway, reutilizar su lockfile verificado o generar y auditar
   uno en staging cuando cambien sus dependencias. Instalar con
   `npm ci --omit=optional --ignore-scripts`.
4. Enlazar `config/.env`, `storage`, `uploads` y `logs` con sus recursos bajo
   `/srv/viax/shared`. Enlazar `workers/dispatch_worker.log` con el archivo
   persistente correspondiente. Preparar `public-api.map` desde la lista
   revisada. Comparar que cada destino sea un PHP existente y que ningún
   script de diagnóstico o directorio interno quede expuesto.
5. Validar PHP y probar migraciones antes de activar el release. Cambiar
   cada enlace `current` creando un enlace temporal en el mismo directorio
   y reemplazándolo con `mv -T`. Reiniciar las unidades exclusivas de PHP,
   realtime y los workers si cambió su código. Ejecutar `nginx -t` y
   recargar Nginx si cambió el vhost o el mapa de rutas.

No usar scripts históricos de limpieza ni copiar el directorio local
`.git`, archivos `.env`, cachés o builds anteriores. Los permisos de
`backend.env` son `0640` con propietario `root` y grupo `viax`.

## PostgreSQL y respaldo

Los respaldos iniciales y `SHA256SUMS` están en `/srv/viax/backups`.
El dump se restauró en `viax_restore_validation`, con acceso público
revocado, y se compararon el esquema, los conteos y el historial.
El respaldo de archivos conserva `/var/www/viax` y la instalación histórica
continúa en su ruta original.

Para un nuevo cambio, generar otro `pg_dump -Fc` de `viax`, verificar su
digest y restaurarlo en una base aislada antes de aplicar SQL. Comparar el
historial y los datos que afecte la migración. Ejecutar el runner con
`DB_NAME` explícito, desde la versión auditada, manteniendo
`VIAX_ALLOW_DATA_MIGRATIONS=0` como valor de producción. El runner usa el
bloqueo de PostgreSQL y admite los checksums de los dos formatos de fin de
línea históricos.

En el corte inicial se aplicó `047_create_trip_tracking_points_phase2.sql`.
`053_account_deletion_system.sql` y `055_legal_acceptance_system.sql`
quedaron selladas por la política de mutaciones. Los checksums, respaldos
y resultados se registran en `/srv/viax/deployment/migrations-*.txt`.

## Salud, logs y aislamiento

```sh
curl -fsS https://viaxcol.online/api/health.php
curl -fsS http://127.0.0.1:19100/health
systemctl is-active viax-php viax-redis viax-realtime
journalctl -u viax-worker@dispatch -n 30 --no-pager
nginx -t
curl -fsS -o /dev/null https://tracon.online/actuator/health/readiness
curl -fsS -o /dev/null https://tracongames.com/
```

Nginx registra en `/var/log/nginx/viax-*.log`. PHP y sus workers escriben
en `/srv/viax/shared/logs` y el journal. El inventario inicial y final
queda en `/srv/viax/deployment/{preflight,postflight}.txt`. Verificar
los hashes de vhosts ajenos y comparar las identidades, las fechas de
inicio y los montajes de contenedores, además de imágenes, redes y volúmenes.
TRACON conserva su propio PostgreSQL, Redis y workers en Docker.

## Verificación de integraciones

La API de salud comprueba PostgreSQL y Redis. Se probó la emisión de un
token PHP y su aceptación por el gateway WebSocket con una cuenta sintética,
PostgreSQL clonado y Redis de prueba. En producción se verificó el rechazo
de una conexión WebSocket anónima. Se comprobaron la cotización, las
imágenes públicas de R2 y la autenticación SMTP por TLS. El proyecto
Firebase autoriza ambos dominios. Quedan por verificar Google Sign-In,
el envío de correo, FCM y los flujos privados con cuentas de prueba.

## Reversión

La alternativa de Web está en `releases/legacy-static-backup`; se
verificaron su HTML y los activos que referencia. Para revertir Web,
cambiar el enlace `web/current` de forma atómica.

El release anterior del Backend es `releases/10f19e0`. Contiene el mapa
restrictivo que deshabilita login, logout y refresh, porque esa versión
tiene un fallback de PHP al Redis histórico. Si se vuelve a ese release,
mantener esas rutas cerradas y verificar el aislamiento antes de
publicar una API autenticada. Reiniciar solo las unidades de VIAX.
Validar y recargar Nginx para aplicar el mapa anterior. El vhost vigente
y la configuración HTTP previa al corte se guardaron bajo `deployment`
y `backups`. Las recuperaciones PostgreSQL se prueban en una base aparte
y requieren reconciliar las escrituras recibidas desde el respaldo antes
de sustituir datos de producción.

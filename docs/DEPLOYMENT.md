# 🚀 Despliegue Viax - Producción VPS

## Producción oficial
- Host: `76.13.114.194`
- Acceso: `ssh root@76.13.114.194`
- Ruta backend: `/var/www/viax/backend`
- URL backend: `http://76.13.114.194`

## Flujo recomendado de despliegue (backend)
1. Subir cambios por SCP/SSH desde local (sin git en servidor):
   - `./backend/scripts/update_server.sh root@76.13.114.194`
2. Conectarse al servidor para verificación:
   - `ssh root@76.13.114.194`
3. Confirmar que no exista metadata git en backend remoto:
   - `test ! -d /var/www/viax/.git && test ! -d /var/www/viax/backend/.git && echo "OK sin git"`
4. Dependencias y migraciones (si aplica un release manual):
   - `cd /var/www/viax/backend`
   - `composer install --no-dev --optimize-autoloader`
   - `php scripts/run_migrations.php`
5. Permisos:
   - `mkdir -p logs uploads`
   - `chmod 755 logs uploads`

## Verificación post-despliegue
- Health:
  - `curl http://76.13.114.194/health.php`
- Sistema:
  - `curl http://76.13.114.194/verify_system_json.php`

## Configuración Flutter para producción
Ejecutar con:
- `flutter run --dart-define=API_BASE_URL=http://76.13.114.194`

## Notas
- Producción oficial y única: servidor VPS `76.13.114.194`.
- Mantener toda referencia de despliegue y verificación apuntando a este servidor.
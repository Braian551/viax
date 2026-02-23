# Guía Rápida: Entornos Viax

## Local
- Base URL: `http://localhost/viax/backend`
- Emulador Android: `http://10.0.2.2/viax/backend`
- Ruta backend: `C:\laragon\www\viax\backend`

## Producción
- Base URL: `http://76.13.114.194`
- SSH: `ssh root@76.13.114.194`
- Ruta backend: `/var/www/viax/backend`

## Cambio rápido
1. `app_config.dart`: development/production.
2. `API_BASE_URL`:
   - Local: `http://localhost/viax/backend`
   - VPS: `http://76.13.114.194`

## Verificación
- Local: `http://localhost/viax/backend/health.php`
- Producción: `http://76.13.114.194/health.php`

## Comandos clave producción
- `ssh root@76.13.114.194`
- `cd /var/www/viax/backend`
- `composer install --no-dev --optimize-autoloader`
- `php migrations/run_migrations.php`
- `curl http://76.13.114.194/health.php`
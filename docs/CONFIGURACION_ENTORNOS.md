# Configuración de Entornos - Viax

## Entornos soportados
- Local (Laragon): `http://localhost/viax/backend`
- Producción (VPS): `http://76.13.114.194`

## Local (Laragon)
- Ruta backend recomendada: `C:\laragon\www\viax\backend`
- Base de datos local: `viax`
- App Flutter local:
  - Navegador: `http://localhost/viax/backend`
  - Emulador Android: `http://10.0.2.2/viax/backend`
  - Dispositivo físico: `http://<IP_LOCAL>/viax/backend`

## Producción (VPS)
- Host: `76.13.114.194`
- Acceso: `ssh root@76.13.114.194`
- Ruta backend: `/var/www/viax/backend`
- URL backend: `http://76.13.114.194`

## Cambio Local ↔ Producción
1. Backend DB config (`backend/config/database.php`): credenciales local/remota.
2. Flutter env (`lib/src/core/config/app_config.dart`): `Environment.development` o `Environment.production`.
3. Base URL (`API_BASE_URL`):
   - Local: `http://localhost/viax/backend`
   - VPS: `http://76.13.114.194`

## Verificación rápida
- Local:
  - `http://localhost/viax/backend/health.php`
  - `http://localhost/viax/backend/verify_system_json.php`
- Producción:
  - `http://76.13.114.194/health.php`
  - `http://76.13.114.194/verify_system_json.php`

## Checklist de despliegue producción
- [ ] Conexión SSH al VPS
- [ ] Código backend actualizado en `/var/www/viax/backend`
- [ ] `composer install --no-dev --optimize-autoloader`
- [ ] `php migrations/run_migrations.php`
- [ ] `health.php` responde `status: ok`
- [ ] Flujos críticos validados
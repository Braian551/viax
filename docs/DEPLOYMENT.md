# 🚀 Despliegue Viax - Producción VPS

## Producción oficial
- Host: `76.13.114.194`
- Acceso: `ssh root@76.13.114.194`
- Ruta backend: `/var/www/viax/backend`
- URL backend: `http://76.13.114.194`

## Flujo recomendado de despliegue (backend)
1. Conectarse al servidor:
   - `ssh root@76.13.114.194`
2. Ir al backend:
   - `cd /var/www/viax/backend`
3. Verificar estado git:
   - `git status --short --branch`
4. Desplegar cambios:
   - Si el árbol está limpio: `git pull origin main`
   - Si hay cambios locales: respaldar o hacer `git stash` antes de `git pull`
5. Dependencias y migraciones:
   - `composer install --no-dev --optimize-autoloader`
   - `php migrations/run_migrations.php`
6. Permisos:
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
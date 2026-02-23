# Resumen de cambios de entorno (actualizado)

## Estado actual
- Entorno local: Laragon con `http://localhost/viax/backend`
- Entorno producción: VPS `http://76.13.114.194`
- Acceso producción: `ssh root@76.13.114.194`

## Archivos clave
- `backend/config/database.php`
- `lib/src/core/config/app_config.dart`
- `docs/DEPLOYMENT.md`
- `docs/CONFIGURACION_ENTORNOS.md`

## Verificación
- Local: `http://localhost/viax/backend/health.php`
- Producción: `http://76.13.114.194/health.php`

## Nota
- Se retiraron referencias antiguas de despliegue para mantener una única referencia de producción (VPS).
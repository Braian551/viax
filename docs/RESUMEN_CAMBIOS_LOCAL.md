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

## Actualización 2026-03-08 (Tarifas mototaxi)
- Endpoint ajustado: `backend/company/pricing.php`.
- Se normalizan tipos de vehículo para evitar pérdida de tarifas por alias legacy:
	- `auto`, `automovil`, `car` -> `carro`
	- `motocarro`, `moto_carga`, `moto carga` -> `mototaxi`
- El GET de tarifas ahora filtra y ordena usando tipos normalizados, corrigiendo casos donde `mototaxi` no aparecía en app/sitioweb.
- El POST/PUT actualiza registros existentes incluso si quedaron con tipo legacy, y los canoniza al guardar.
- Limpieza de seguridad local: se eliminó `remote_env.txt` para evitar exposición accidental de credenciales.
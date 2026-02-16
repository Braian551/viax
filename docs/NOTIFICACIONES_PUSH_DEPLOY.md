# Despliegue y validación de notificaciones push (Viax)

## 1. Requisitos previos

- Backend desplegado con la migración `backend/migrations/027_create_notifications_system.sql` aplicada.
- App Flutter compilando con `firebase_messaging` y `firebase_core`.
- Proyecto Firebase configurado para Android/iOS (archivos de configuración ya presentes en el proyecto).
- Clave de servidor FCM disponible en entorno backend.

## 2. Configurar variables en VPS

Servidor objetivo:

- `ssh root@76.13.114.194`

Definir una de estas variables (preferir `FCM_SERVER_KEY`):

- `FCM_SERVER_KEY`
- `FIREBASE_SERVER_KEY` (fallback)

Ejemplo (ajustar según tu runtime/proceso):

- `export FCM_SERVER_KEY="TU_SERVER_KEY_FCM"`

Luego reinicia el servicio PHP/web correspondiente para que tome variables de entorno.

## 3. Endpoints nuevos disponibles

- `POST /notifications/register_push_token.php`
- `POST /notifications/unregister_push_token.php`

Payload registro:

```json
{
  "usuario_id": 123,
  "token": "fcm_token",
  "plataforma": "android",
  "device_id": "opcional",
  "device_name": "Flutter App"
}
```

Payload desregistro:

```json
{
  "usuario_id": 123,
  "token": "fcm_token"
}
```

## 4. Eventos backend conectados

Se crean notificaciones persistidas y se intenta push para:

- Aceptación de viaje (`accept_trip_request.php`).
- Cambios de estado de viaje (`update_trip_status.php`): llegó, en curso, completada, cancelada.
- Mensaje nuevo de chat (`chat/send_message.php`).
- Aprobación de conductor/documentación (`admin/aprobar_conductor.php`).

## 5. Smoke test rápido backend (cURL)

Registrar token:

```bash
curl -X POST "https://TU_BACKEND/notifications/register_push_token.php" \
  -H "Content-Type: application/json" \
  -d '{"usuario_id":123,"token":"TOKEN_FCM","plataforma":"android","device_name":"Prueba"}'
```

Esperado:

- `{"success":true,...}`
- fila activa en `tokens_push_usuario`.

## 6. Validación E2E en app

1. Iniciar sesión en app con usuario real.
2. Verificar que se registre token (llamado al endpoint de registro).
3. Disparar un evento real (por ejemplo, enviar chat o cambio de estado de viaje).
4. Confirmar:
   - llega push al dispositivo;
   - aparece registro en `notificaciones_usuario`;
   - pantalla de notificaciones muestra el ítem (y filtros por categoría funcionan).

## 7. Troubleshooting rápido

- Si no llega push y sí se crea notificación:
  - revisar que `FCM_SERVER_KEY` esté presente en proceso PHP;
  - validar token activo en `tokens_push_usuario`;
  - verificar preferencias en `configuracion_notificaciones_usuario` (`push_enabled` y flags por tipo).
- Si no se crea notificación:
  - revisar logs del endpoint de negocio que dispara el evento;
  - validar IDs de usuario destino y estado de viaje.

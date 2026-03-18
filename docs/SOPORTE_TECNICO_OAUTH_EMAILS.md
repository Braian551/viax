# Soporte Tecnico, OAuth y Plantillas de Correo

## Objetivo
Este documento resume la arquitectura implementada para:

1. Rol dedicado de soporte tecnico.
2. Operacion de tickets desde el sitio web.
3. Flujo de Google Sign-In web robusto en produccion.
4. Unificacion visual de correos salientes.

## Rol soporte tecnico

### Backend
- Nuevo rol permitido en `usuarios.tipo_usuario`: `soporte_tecnico`.
- Migracion: `backend/migrations/054_support_role_and_ticket_logs.sql`.

### Web
- Nuevo routing principal: `/soporte`.
- El sidebar de `AdminLayout` se adapta por rol:
  - `administrador`: menu completo de administracion.
  - `soporte_tecnico`: menu operativo de soporte (bandeja + notificaciones).

### Administracion del rol
- Desde `AdminUsers` se puede asignar `soporte_tecnico` al editar usuarios.
- El backend valida roles permitidos en `admin/user_management.php`.

## Soporte (tickets y chat)

### Endpoints
- `support/get_tickets.php`: ahora soporta modo agente y filtros operativos.
- `support/get_ticket_messages.php`: acceso para propietario o agente.
- `support/send_message.php`: mensajes de usuario o agente con transicion de estado.
- `support/create_ticket.php`: anti-spam + prioridad + log.
- `support/update_ticket.php` (nuevo): estado/prioridad/asignacion por agente.
- `support/get_ticket_logs.php` (nuevo): historial operativo de ticket.

### Trazabilidad
- Tabla `ticket_soporte_logs` para auditoria de acciones sobre tickets.

## Google Sign-In web

### Cambios de frontend
- El flujo ahora prioriza GIS (Google Identity Services) con precarga de script + client_id.
- Se evita abrir popup tarde para reducir `popup_failed`.
- Firebase queda como fallback secundario.

### Requisito de consola (obligatorio en produccion)
Para evitar `domain is not authorized for OAuth operations`, configurar en Firebase:

1. Firebase Console -> Authentication -> Settings -> Authorized domains.
2. Agregar `viaxcol.online` (y dominio adicional si aplica, por ejemplo `www.viaxcol.online`).
3. Verificar en Google Cloud Console -> OAuth client (Web) que el origen JS autorizado incluya `https://viaxcol.online`.

## Plantillas de correo

### Unificacion aplicada
- `backend/utils/Mailer.php` usa layout alineado al estilo moderno de Viax.
- Si no existe logo embebido local, hace fallback a `EMAIL_LOGO_URL` y luego a URL oficial.
- `backend/services/EmailService.php` usa logo por defecto `https://viaxcol.online/logo.png`.

### Variable recomendada
- Definir en backend `.env`: `EMAIL_LOGO_URL=https://viaxcol.online/logo.png`

## Notas operativas
- El dashboard operativo de soporte se mantiene en sitio web.
- La app movil puede conservar accesos de ayuda para clientes/conductores/empresa,
  pero la gestion completa de tickets se centraliza en web por rol soporte tecnico.

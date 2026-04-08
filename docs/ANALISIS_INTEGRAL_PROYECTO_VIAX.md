# Analisis integral archivo por archivo - Viax

Fecha del analisis: 2026-03-28
Repositorio analizado: C:\\Flutter\\viax
Documento generado por: revision tecnica de codigo + documentacion interna

## 1) Objetivo y alcance

Este documento responde a la solicitud de analizar el proyecto "archivo por archivo", explicando:

- De que trata el producto.
- Cual es la logica de negocio principal.
- Como esta estructurada la empresa/plataforma.
- Que hace cada bloque de archivos mas importante.

Importante sobre alcance real:

- El repositorio tiene inventario tecnico consolidado en [docs/ANEXO_INVENTARIO_ARCHIVOS.csv](./ANEXO_INVENTARIO_ARCHIVOS.csv), con 1,360 archivos propios inventariados.
- Este informe prioriza analisis funcional profundo en archivos con logica de negocio (backend/app/web), no en artefactos generados o terceros.

## 2) Que es Viax y que empresa representa

Viax es una plataforma de movilidad y operacion de transporte multi-actor, con cuatro grandes perfiles:

- Cliente: solicita viajes, ve precio estimado, sigue viaje en tiempo real, califica, reporta y bloquea.
- Conductor: recibe/acepta/rechaza servicios, ejecuta viaje con tracking GPS, ve ganancias y deudas.
- Empresa de transporte: administra conductores, tarifas, pagos, deuda de comisiones y reportes.
- Administracion/plataforma: monitorea operacion, usuarios, finanzas, deuda de empresas, auditoria y gobierno.

En documentacion interna se referencia la sociedad **VIAX TECHNOLOGY S.A.S.** (tambien aparece NIT en plantillas y reportes).

## 3) Resumen tecnico cuantitativo

Datos cruzados entre codigo y anexos/documentos:

- Archivos inventariados (propios): 1,360.
- Distribucion principal por raiz:
  - `lib`: 545
  - `backend`: 360
  - `sitioweb`: 140
  - `docs`: 78
- Distribucion por extension (top):
  - `.dart`: 545
  - `.php`: 260
  - `.md`: 102
  - `.jsx`: 75
  - `.sql`: 69
- Lineas de texto aproximadas inventariadas: 256,098.

## 4) Arquitectura general del producto

### 4.1 Canales

- App movil Flutter (`lib/`) para cliente, conductor, empresa y admin.
- Backend PHP (`backend/`) con API modular, Redis, workers, pricing, matching, tracking, legal/security.
- Sitio web React/Vite (`sitioweb/`) con landing, auth y dashboards por rol.

### 4.2 Stack dominante

- Frontend app: Flutter + Provider + Dio + Mapbox + Firebase (core/messaging) + geolocalizacion.
- Backend: PHP + PostgreSQL + Redis + PHPMailer + scripts/worker por procesos.
- Web: React + React Router + Vite + servicios HTTP al backend.

### 4.3 Patron de operacion

- Controladores/endpoints delgados.
- Logica pesada en servicios (`backend/services`) y workers (`backend/workers`).
- Redis usado para estado caliente, colas, locks y telemetria.
- PostgreSQL como fuente durable de negocio/finanzas/historial.

## 5) Logica de negocio principal (end-to-end)

### 5.1 Onboarding y acceso

- Registro/login con validaciones de dispositivo (`user_devices`), bloqueo por intentos y verificacion por codigo.
- Flujo de reactivacion de cuenta inactiva (por contrasena o identidad Google segun endpoint).
- Guarda sesion y perfil para experiencia multi-rol.

### 5.2 Solicitud y asignacion de viaje

- Cliente crea solicitud (`create_trip_request.php`) con idempotencia y validacion de coordenadas.
- Se valida seguridad (HMAC/fingerprint/rate limit) y aceptacion legal vigente.
- Se calcula previsualizacion: candidatos cercanos + ETA + pricing dinamico + surge.
- La solicitud entra a cola Redis para despacho asincrono.
- `dispatch_worker.php` ejecuta rondas, ofertas por lotes, timeout, cooldown y cancelacion por no asignacion.

### 5.3 Ejecucion del viaje y tracking

- Conductor acepta/rechaza con control de concurrencia.
- Estado de viaje se rige por maquina de estados (`TripStateMachine`).
- Tracking en tiempo real:
  - puntos GPS,
  - filtros anti-salto,
  - acumulacion de distancia/tiempo,
  - stream SSE al cliente,
  - persistencia por lotes con Redis Streams + worker.

### 5.4 Cierre, cobro y comisiones

- Finalizacion congela metricas canonicas y precio final.
- Se registra resumen financiero para inmutabilidad historica (evitar recalculo retroactivo por cambios de tarifas).
- Se actualiza disponibilidad de conductor, notificaciones y metricas de empresa/plataforma.

### 5.5 Gobierno, soporte y confianza

- Sistema de reportes y bloqueos entre usuarios (solo si hubo viaje compartido).
- Sistema de tickets de soporte con logs y roles de atencion.
- Modulo "conductores de confianza" con score por historial, calificacion, proximidad y popularidad.

### 5.6 Capa empresa y capa plataforma

- Empresa configura tarifas por tipo vehiculo, revisa deuda y reporta pagos.
- Admin revisa pagos, confirma/rechaza comprobantes, maneja cuenta bancaria destino y ve ganancias/plataforma.

## 6) Analisis archivo por archivo - Backend (nucleo funcional)

## 6.1 Entrada, configuracion y core

| Archivo | Funcion principal |
|---|---|
| `backend/index.php` | Router principal por prefijos (`auth`, `user`, `conductor`, `admin`, etc.). |
| `backend/config/bootstrap.php` | Carga `.env`, helper `env_value`, timezone app. |
| `backend/config/app.php` | Bootstrap de includes compartidos (DB/config/redis/cache). |
| `backend/config/config.php` | Helpers JSON (`getJsonInput`, `sendJsonResponse`) y cabeceras base. |
| `backend/config/database.php` | Conexion PostgreSQL por variables de entorno. |
| `backend/config/redis.php` | Configuracion de Redis para cache/colas/locks. |
| `backend/core/Cache.php` | Wrapper resiliente para Redis (get/set/sets). |
| `backend/core/Auth.php` | Helpers bearer token y sesiones cacheadas en Redis. |
| `backend/core/RateLimiter.php` | Limite de tasa simple por key en Redis. |
| `backend/core/Request.php` | Abstraccion de request HTTP (utilidad base). |
| `backend/core/Response.php` | Abstraccion de respuesta HTTP (utilidad base). |
| `backend/core/Router.php` | Router modular alternativo para endpoints estructurados. |
| `backend/core/Validator.php` | Validaciones reutilizables de payload/entrada. |

## 6.2 Middleware

| Archivo | Funcion principal |
|---|---|
| `backend/middleware/SecurityMiddleware.php` | HMAC + nonce + fingerprint + score de riesgo + enforcement modes. |
| `backend/middleware/LegalMiddleware.php` | Bloquea acceso si no coincide version legal aceptada por rol. |
| `backend/middleware/AuthMiddleware.php` | Middleware base de autenticacion para endpoints protegidos. |
| `backend/middleware/RateLimitMiddleware.php` | Limites de peticiones a nivel endpoint/actor. |

## 6.3 Servicios de negocio

| Archivo | Funcion principal |
|---|---|
| `backend/services/matching_service.php` | Ranking multi-factor de conductores (distancia, rating, aceptacion, cancelacion, idle, ETA). |
| `backend/services/driver_service.php` | GEO/disponibilidad/heartbeat/grid index/sharding por ciudad. |
| `backend/services/eta_service.php` | Estimacion ETA con fallback y cache. |
| `backend/services/pickup_eta_service.php` | ETA de recogida en fase de busqueda. |
| `backend/services/pricing_service.php` | Pricing dinamico base (distance/time/traffic/surge). |
| `backend/services/traffic_pricing.php` | Reglas de recargos (trafico, festivo Colombia, nocturno). |
| `backend/services/traffic_service.php` | Integracion/consulta de trafico para pricing y ETA. |
| `backend/services/traffic_cache.php` | Cache de trafico por zonas/rutas. |
| `backend/services/traffic_zone_resolver.php` | Resuelve llaves discretas de zona para trafico/surge. |
| `backend/services/trip_state_machine.php` | Estados canonicos y transiciones permitidas del viaje. |
| `backend/services/tracking_service.php` | Servicios auxiliares de tracking (consolidacion runtime). |
| `backend/services/places_search_service.php` | Busqueda inteligente de lugares (recientes + Google Places + cache). |
| `backend/services/EmailService.php` | Envio transaccional de emails con limites y plantillas. |
| `backend/services/EmailRateLimiter.php` | Anti-abuso de email por IP/usuario/accion. |
| `backend/services/SmtpMailProvider.php` | Proveedor SMTP PHPMailer. |
| `backend/services/SecurityLogger.php` | Logging de seguridad estructurado. |
| `backend/services/TripService.php` | Servicio transversal de operaciones de viaje (modular). |
| `backend/services/UserService.php` | Servicio transversal de operaciones de usuario (modular). |
| `backend/services/LocationService.php` | Utilidades de localizacion para varios flujos. |
| `backend/services/roads_snap_service.php` | Ajuste de puntos GPS a vias (map matching). |
| `backend/services/DriverService.php` | Variante orientada a capa OO/repository. |
| `backend/services/MatchingService.php` | Variante OO del matching (compatibilidad/modularizacion). |
| `backend/services/PricingService.php` | Variante OO del pricing (compatibilidad/modularizacion). |

## 6.4 Workers y procesamiento asincrono

| Archivo | Funcion principal |
|---|---|
| `backend/workers/dispatch_worker.php` | Motor asincrono de asignacion con batches, timeout, locks y cancelacion. |
| `backend/workers/zone_cache_worker.php` | Precalcula top conductores por grid para acelerar dispatch. |
| `backend/workers/surge_pricing_worker.php` | Calcula multiplicador surge por demanda/oferta por zona. |
| `backend/workers/driver_reposition_worker.php` | Sugiere reposicionamiento a conductores inactivos por hotspots. |
| `backend/workers/tracking_stream_worker.php` | Consume Redis Streams de tracking y persiste por lotes. |
| `backend/workers/account_deletion_worker.php` | Ejecuta eliminacion irreversible/anonimizacion de cuentas vencidas. |
| `backend/workers/supervisor_tracking_worker.conf` | Configuracion de supervisor para worker tracking. |

## 6.5 Endpoints Auth

| Archivo | Funcion principal |
|---|---|
| `backend/auth/register.php` | Registro de usuario + direccion inicial + dispositivo confiable inicial. |
| `backend/auth/login.php` | Login con control de intentos, bloqueo por dispositivo y estado de cuenta. |
| `backend/auth/check_device.php` | Evalua dispositivo (`trusted`, `needs_verification`, `locked`). |
| `backend/auth/verify_code.php` | Verificacion de codigo; puede marcar dispositivo confiable. |
| `backend/auth/check_user.php` | Validacion de existencia de usuario. |
| `backend/auth/email_service.php` | Endpoint de envio de codigo/correos auth. |
| `backend/auth/profile.php` | Obtencion de perfil de usuario. |
| `backend/auth/profile_update.php` | Actualizacion de perfil/ubicacion de usuario. |
| `backend/auth/update_profile.php` | Variante de actualizacion de perfil. |
| `backend/auth/update_phone.php` | Cambio/registro de telefono. |
| `backend/auth/change_password.php` | Cambio de contrasena con verificacion. |
| `backend/auth/session_key.php` | Emision/renovacion de session key para firma HMAC. |

## 6.6 Endpoints User

| Archivo | Funcion principal |
|---|---|
| `backend/user/create_trip_request.php` | Crea solicitud con validaciones, legal/security, idempotencia, matching, ETA, pricing y enqueue dispatch. |
| `backend/user/trip_preview.php` | Preview de viaje reutilizando `CompanyService`. |
| `backend/user/get_companies_by_municipality.php` | Descubre empresas/vehiculos por municipio y disponibilidad. |
| `backend/user/update_trip_search_company.php` | Cambia empresa objetivo durante busqueda de conductor. |
| `backend/user/find_nearby_drivers.php` | Endpoint de candidatos cercanos para flujo cliente. |
| `backend/user/get_trip_status.php` | Estado integral de viaje con long-polling optimizado y firma. |
| `backend/user/stream_trip_updates.php` | Stream SSE de tracking/estado/ETA para cliente. |
| `backend/user/cancel_trip_request.php` | Cancelacion de solicitud por cliente con controles de estado. |
| `backend/user/check_active_trip.php` | Consulta de viaje activo actual del cliente. |
| `backend/user/check_solicitudes.php` | Verificacion de solicitudes pendientes/estado general. |
| `backend/user/get_trip_history.php` | Historial de viajes del cliente. |
| `backend/user/get_payment_summary.php` | Resumen de pagos/estados de cobro. |
| `backend/user/rate_trip.php` | Calificacion posterior al viaje desde cliente. |
| `backend/user/search_places.php` | Busqueda de lugares con recientes+Google. |
| `backend/user/prefetch_route.php` | Precarga de ruta/metricas para UI rapida. |
| `backend/user/save_recent_search.php` | Guarda busquedas recientes. |
| `backend/user/get_recent_searches.php` | Devuelve recientes del usuario. |
| `backend/user/get_company_details.php` | Detalle extendido de empresa seleccionable. |
| `backend/user/get_favorite_drivers.php` | Lista conductores favoritos. |
| `backend/user/toggle_favorite_driver.php` | Marca/desmarca conductor como favorito. |
| `backend/user/block_user.php` | Bloquea usuario (si hubo viaje compartido). |
| `backend/user/unblock_user.php` | Levanta bloqueo entre usuarios. |
| `backend/user/is_blocked.php` | Estado de bloqueo entre dos usuarios. |
| `backend/user/report_user.php` | Reporte moderacion contra otro usuario (con validaciones). |

## 6.7 Endpoints Conductor

| Archivo | Funcion principal |
|---|---|
| `backend/conductor/accept_trip_request.php` | Aceptacion con concurrencia, lock y notificacion a cliente. |
| `backend/conductor/reject_trip_request.php` | Rechazo con cooldown y senal al dispatch. |
| `backend/conductor/heartbeat.php` | Heartbeat de presencia/online para evitar conductores "fantasma". |
| `backend/conductor/update_trip_status.php` | Transiciones de estado, cierre, congelacion de metricas y notificaciones. |
| `backend/conductor/driver_auth.php` | Sesion de conductor en Redis (12h) + validacion por endpoint. |
| `backend/conductor/update_location.php` | Actualiza ubicacion/estado para matching. |
| `backend/conductor/actualizar_ubicacion.php` | Variante legacy de actualizacion de ubicacion. |
| `backend/conductor/actualizar_disponibilidad.php` | Activa/desactiva disponibilidad de conductor. |
| `backend/conductor/get_pending_requests.php` | Solicitudes pendientes para conductor. |
| `backend/conductor/get_solicitudes_pendientes.php` | Variante de solicitudes pendientes. |
| `backend/conductor/get_viajes_activos.php` | Viajes activos del conductor. |
| `backend/conductor/get_historial.php` | Historial de viajes del conductor. |
| `backend/conductor/get_ganancias.php` | Resumen de ingresos/ganancias. |
| `backend/conductor/get_estadisticas.php` | Estadisticas operativas del conductor. |
| `backend/conductor/get_profile.php` | Perfil completo de conductor. |
| `backend/conductor/update_profile.php` | Edicion de perfil conductor. |
| `backend/conductor/update_vehicle.php` | Edicion de vehiculo. |
| `backend/conductor/update_license.php` | Edicion de licencia/documento legal. |
| `backend/conductor/upload_document.php` | Subida de un documento. |
| `backend/conductor/upload_documents.php` | Subida masiva de documentos. |
| `backend/conductor/upload_vehicle_photo.php` | Sube foto del vehiculo. |
| `backend/conductor/submit_verification.php` | Envia perfil/documentos a revision. |
| `backend/conductor/vehicle_catalog.php` | Catalogo de tipos/marcas/modelos de vehiculo. |
| `backend/conductor/get_demand_zones.php` | Devuelve zonas con demanda para conductor. |
| `backend/conductor/debt_payment_context.php` | Contexto de deuda/comisiones del conductor. |
| `backend/conductor/report_debt_payment.php` | Reporte de pago de deuda por conductor. |
| `backend/conductor/get_pendientes_empresa.php` | Pendientes del conductor con su empresa. |
| `backend/conductor/search_companies.php` | Busqueda de empresas para vinculacion. |
| `backend/conductor/solicitudes_vinculacion.php` | Flujo de solicitudes de vinculacion empresa-conductor. |
| `backend/conductor/verify_biometrics.php` | Validacion biometrica (integracion Python/face). |
| `backend/conductor/activar_conductor.php` | Activacion operativa del perfil conductor. |
| `backend/conductor/info.php` | Informacion resumida (legacy/support). |
| `backend/conductor/get_info.php` | Informacion extendida (legacy/support). |
| `backend/conductor/tracking/register_point.php` | Registra punto GPS unitario con filtros fisicos y precio parcial. |
| `backend/conductor/tracking/register_points_batch.php` | Ingesta batch de tracking para mejor rendimiento. |
| `backend/conductor/tracking/get_tracking.php` | Consulta de tracking historico/actual de viaje. |
| `backend/conductor/tracking/finalize.php` | Cierra tracking, consolida metricas reales, aplica recargos y precio final. |
| `backend/conductor/tracking/tracking_ingest_service.php` | Servicio de ingesta tracking desacoplado del endpoint. |
| `backend/conductor/tracking/tracking_schema_helpers.php` | Helpers de esquema/columnas para compatibilidad migraciones. |

## 6.8 Endpoints Company

| Archivo | Funcion principal |
|---|---|
| `backend/company/dashboard_stats.php` | KPI principal de empresa (operacion, ingresos, rendimiento). |
| `backend/company/pricing.php` | Gestion completa de tarifas por empresa y tipo de vehiculo. |
| `backend/company/drivers.php` | Gestion/listado de conductores de empresa. |
| `backend/company/vehicles.php` | Gestion/listado de vehiculos empresariales. |
| `backend/company/reports.php` | Reportes operativos/financieros para empresa. |
| `backend/company/reports_pdf.php` | Exportacion de reportes en PDF. |
| `backend/company/get_balance.php` | Balance y deuda de empresa. |
| `backend/company/get_debtors.php` | Conductores/entidades deudoras relacionadas. |
| `backend/company/get_conductor_transactions.php` | Transacciones por conductor. |
| `backend/company/platform_debt_context.php` | Contexto de deuda empresa hacia plataforma. |
| `backend/company/report_platform_payment.php` | Empresa reporta pago a plataforma con comprobante (R2). |
| `backend/company/debt_payment_reports.php` | Revision/aprobacion/rechazo/confirmacion de reportes de pago. |
| `backend/company/colombia_banks.php` | Catalogo de bancos para transferencias. |
| `backend/company/conductores_documentos.php` | Estado documental de conductores por empresa. |

## 6.9 Endpoints Admin

| Archivo | Funcion principal |
|---|---|
| `backend/admin/dashboard_stats.php` | Dashboard global de operacion. |
| `backend/admin/user_management.php` | Administracion de usuarios/roles/estados. |
| `backend/admin/audit_logs.php` | Consulta de logs de auditoria. |
| `backend/admin/app_config.php` | Configuracion operativa global de app. |
| `backend/admin/empresas.php` | Gestion de empresas de transporte. |
| `backend/admin/aprobar_conductor.php` | Aprobacion de conductor/documentos. |
| `backend/admin/rechazar_conductor.php` | Rechazo de conductor/documentos. |
| `backend/admin/get_conductores_documentos.php` | Consulta documental para revision admin. |
| `backend/admin/get_documentos_historial.php` | Historial de revisiones documentales. |
| `backend/admin/get_pricing_configs.php` | Consulta global de configuraciones de tarifa. |
| `backend/admin/update_pricing_config.php` | Actualizacion de tarifas globales/plataforma. |
| `backend/admin/platform_earnings.php` | Ganancias/plataforma por periodos y deuda por cobrar. |
| `backend/admin/registrar_pago_empresa.php` | Registra pago empresa->plataforma y reduce saldo. |
| `backend/admin/registrar_pago_comision.php` | Registro de pago de comisiones (capa admin). |
| `backend/admin/update_empresa_commission.php` | Ajuste de porcentaje de comision por empresa. |
| `backend/admin/empresa_payment_reports.php` | Revisa comprobantes de pago enviados por empresas. |
| `backend/admin/empresas_deudoras.php` | Ranking/listado de empresas con deuda. |
| `backend/admin/facturas.php` | Gestion de facturacion. |
| `backend/admin/generate_invoice_pdf.php` | Genera factura PDF. |
| `backend/admin/bank_config.php` | Configura cuenta bancaria/Nequi destino de pagos. |
| `backend/admin/emisor_profile.php` | Perfil fiscal de emisor principal. |
| `backend/admin/user_reports.php` | Backoffice de moderacion sobre reportes de usuarios. |

## 6.10 Modulos complementarios backend

| Archivo | Funcion principal |
|---|---|
| `backend/support/create_ticket.php` | Crea ticket con anti-spam y notificacion a agentes. |
| `backend/support/update_ticket.php` | Cambia estado/prioridad/asignacion del ticket. |
| `backend/support/send_message.php` | Mensajeria de ticket (usuario/agente). |
| `backend/support/get_tickets.php` | Lista de tickets con filtros. |
| `backend/support/get_ticket_messages.php` | Mensajes de ticket. |
| `backend/support/get_ticket_logs.php` | Bitacora de cambios en ticket. |
| `backend/support/get_categories.php` | Catalogo de categorias soporte. |
| `backend/support/request_callback.php` | Solicitud de devolucion de llamada. |
| `backend/support/_support_auth.php` | Helpers de autenticacion/autorizacion de soporte. |
| `backend/chat/send_message.php` | Chat cliente-conductor durante viaje activo + regla de bloqueos. |
| `backend/chat/get_messages.php` | Mensajes de chat por viaje. |
| `backend/chat/mark_as_read.php` | Marca mensajes leidos. |
| `backend/chat/get_unread_count.php` | Cuenta no leidos de chat. |
| `backend/chat/stream_messages.php` | Streaming de mensajes de chat. |
| `backend/notifications/create_notification.php` | Alta de notificacion. |
| `backend/notifications/get_notifications.php` | Lista notificaciones usuario. |
| `backend/notifications/get_unread_count.php` | Conteo no leidas. |
| `backend/notifications/mark_as_read.php` | Marca notificaciones como leidas. |
| `backend/notifications/delete_notification.php` | Elimina notificaciones. |
| `backend/notifications/get_settings.php` | Obtiene preferencias de notificacion. |
| `backend/notifications/update_settings.php` | Actualiza preferencias de notificacion. |
| `backend/notifications/register_push_token.php` | Registra token push por dispositivo. |
| `backend/notifications/unregister_push_token.php` | Revoca token push. |
| `backend/location_sharing/create_share.php` | Crea token publico para compartir ubicacion. |
| `backend/location_sharing/update_location.php` | Actualiza ubicacion de enlace compartido. |
| `backend/location_sharing/get_location.php` | Consulta ubicacion por token compartido. |
| `backend/location_sharing/stop_share.php` | Finaliza sesion de compartir ubicacion. |
| `backend/account/delete-request.php` | Solicitud/confirmacion de eliminacion de cuenta (ventana de 15 dias). |
| `backend/account/reactivate.php` | Reactivacion de cuenta inactiva (password/Google). |
| `backend/legal/current_version.php` | Version legal vigente por rol. |
| `backend/legal/accept.php` | Registro de aceptacion legal con hash y metadata. |
| `backend/payment/report_payment_status.php` | Doble confirmacion de pago y creacion de disputa. |
| `backend/payment/check_dispute_status.php` | Consulta de disputa activa por usuario. |
| `backend/payment/resolve_dispute.php` | Resolucion de disputa y desbloqueo de cuentas. |
| `backend/rating/submit_rating.php` | Registro/actualizacion de calificacion y recalculo de promedios. |
| `backend/rating/get_ratings.php` | Consulta de calificaciones. |
| `backend/rating/get_trip_summary.php` | Resumen para pantalla de calificacion. |
| `backend/rating/confirm_cash_payment.php` | Confirmacion de pago en efectivo ligada al viaje. |
| `backend/confianza/ConfianzaService.php` | Motor de score de confianza cliente-conductor. |
| `backend/confianza/calculate_score.php` | Endpoint/calculadora de score de confianza. |
| `backend/utils/NotificationHelper.php` | Capa de alto nivel para crear notificaciones y push. |
| `backend/utils/PushNotificationService.php` | Envio push a dispositivos registrados. |
| `backend/utils/SensitiveDataCrypto.php` | Cifrado/descifrado de datos sensibles (AES). |
| `backend/utils/BlockHelper.php` | Reglas de bloqueo y relacion por viaje compartido. |
| `backend/utils/Mailer.php` | Envio email utilitario (wrappers). |
| `backend/utils/PdfGenerator.php` | Generacion de PDF para reportes/facturas. |
| `backend/utils/FinancialAccessControl.php` | Control de acceso a datos financieros sensibles. |
| `backend/r2_proxy.php` | Proxy para servir archivos almacenados en Cloudflare R2. |
| `backend/config/R2Service.php` | Cliente firmado S3-compatible para R2 (upload/get/delete/list). |

## 6.11 Migraciones y scripts

- `backend/migrations/*.sql` define evolucion de dominio: seguridad dispositivo, pricing, tracking, legal acceptance, reportes usuarios, cifrado financiero, deuda empresa/plataforma, etc.
- `backend/scripts/*.php` incluye mantenimiento/migracion/worker auxiliares (tracking queue, migraciones, archivado, legal, seguridad).
- `backend/python_services/verify_face.py` sugiere apoyo de biometria para verificacion.

## 7) Analisis archivo por archivo - App Flutter (`lib/`)

Resumen de estructura:

- `lib/main.dart`: bootstrap completo (Firebase, notificaciones, secrets, DI, conectividad, cola offline).
- `lib/src/routes/app_router.dart`: routing por rol y por flujo (auth, legal, user, conductor, admin, empresa).
- `lib/src/core/*`: red, seguridad, utilidades, offline queue.
- `lib/src/global/*`: servicios transversales (auth, legal links, notificaciones, perfil, ubicacion, chat).
- `lib/src/features/*`: modulos funcionales por rol.

Archivos Flutter clave de logica:

| Archivo | Funcion principal |
|---|---|
| `lib/main.dart` | Inicializacion global de servicios, providers y manejo de errores. |
| `lib/src/routes/app_router.dart` | Mapa de rutas multirol y guardas legales. |
| `lib/src/core/offline/trip_command_queue.dart` | Cola SQLite de comandos criticos de viaje para resiliencia offline. |
| `lib/src/core/network/dio_legal_interceptor.dart` | Inyeccion de headers de seguridad + redireccion por incumplimiento legal. |
| `lib/src/global/services/auth/user_service.dart` | Registro/login/perfil/sesion local y utilidades de auth. |
| `lib/src/features/user/services/trip_request_service.dart` | Solicitud de viaje y consumo de preview/matching. |
| `lib/src/features/user/services/trip_sse_service.dart` | Consumo SSE con reconexion para updates en vivo. |
| `lib/src/features/user/services/driver_tracking_stream_service.dart` | Stream/estado del conductor en mapa cliente. |
| `lib/src/features/user/services/driver_position_predictor.dart` | Prediccion de posicion entre eventos para suavidad visual. |
| `lib/src/features/conductor/services/trip_tracking_service.dart` | Captura GPS, sync batch y finalizacion con backend tracking. |
| `lib/src/features/conductor/services/resilient_conductor_service.dart` | Operaciones conductor robustas ante fallos de red. |
| `lib/src/features/conductor/services/debt_payment_service.dart` | Flujo de reporte/estado de pago de deuda del conductor. |
| `lib/src/features/legal/services/legal_content_service.dart` | Carga legal remota/local con fallback y parseo robusto. |
| `lib/src/features/company/*` | UI y providers para operacion financiera/operativa empresa. |
| `lib/src/features/admin/*` | UI y providers para gobierno de plataforma. |

Nota: la app contiene 545 archivos `.dart`; para inventario exhaustivo por ruta usar el CSV anexo.

## 8) Analisis archivo por archivo - Sitio web (`sitioweb/`)

Estructura funcional:

- `sitioweb/src/main.jsx`: bootstrap React + BrowserRouter.
- `sitioweb/src/App.jsx`: enrutamiento principal y layouts por rol.
- `sitioweb/src/components/routing/RoleRoute.jsx`: proteccion por rol.
- `sitioweb/src/features/auth/context/AuthContext.jsx`: estado auth, login, Google flow.
- `sitioweb/src/features/{admin,empresa,cliente,conductor}`: dashboards operativos por perfil.
- `sitioweb/src/features/shared/services/*`: clientes API para soporte, notificaciones, moderacion.
- `sitioweb/scripts/export-legal-content.mjs`: sincroniza contenido legal web->app.
- `sitioweb/scripts/prerender-routes.mjs`: prerender SEO estatico para rutas publicas.

Archivos web clave:

| Archivo | Funcion principal |
|---|---|
| `sitioweb/src/App.jsx` | Rutas publicas + privadas por rol (`admin`, `soporte`, `cliente`, `conductor`, `empresa`). |
| `sitioweb/src/components/routing/RoleRoute.jsx` | Guardia de autorizacion por `tipo_usuario`. |
| `sitioweb/src/features/auth/context/AuthContext.jsx` | Sesion local, login, registro, Google sign-in y logout. |
| `sitioweb/src/config/env.js` | Definicion de `API_BASE_URL` y `AUTH_API_URL`. |
| `sitioweb/src/config/httpClient.js` | Wrapper HTTP con manejo de errores estandarizado. |
| `sitioweb/src/features/shared/services/notificationService.js` | API de notificaciones del dashboard web. |
| `sitioweb/src/features/shared/services/supportService.js` | API de tickets/mensajes soporte y reportes usuario. |
| `sitioweb/src/features/shared/services/userModerationService.js` | API de reportes/moderacion de usuarios. |
| `sitioweb/scripts/export-legal-content.mjs` | Exporta `legal_content.json` a web y app Flutter. |
| `sitioweb/scripts/prerender-routes.mjs` | Genera HTML prerender para SEO y contenido visible inicial. |

## 9) Dominio de datos y migraciones (lectura de negocio)

El set de migraciones evidencia evolucion de negocio real, no solo MVP:

- Seguridad: `008_device_security.sql`, `055_security_events_table.sql`.
- Pricing: `007_*`, `023_company_pricing.sql`, `025_company_commission_system.sql`.
- Tracking real-time: `034_viaje_tracking_realtime.sql`, `041_tracking_ingestion_optimization.sql`, `048_tracking_stream_upgrade.sql`, `047_create_trip_tracking_points_phase2.sql`.
- Flujo empresa-plataforma: `039_debt_payment_transfer_flow.sql`, `044_empresa_admin_payment_system.sql`, `045_admin_emisor_fiscal.sql`.
- Legal: `055_legal_acceptance_system.sql`, `058_*`, `059_*`.
- Moderacion: `056_blocked_users_system.sql`, `057_user_reports_system.sql`.
- Ciclo de vida de cuenta: `053_account_deletion_system.sql`.

## 10) Hallazgos tecnicos y de riesgo (importantes)

### 10.1 Fortalezas

- Arquitectura funcional amplia con capas cliente/conductor/empresa/admin.
- Dispatch + tracking + pricing dinamico + workers + cache, bien orientado a operacion real.
- Buen uso de Redis para estado caliente y baja latencia.
- Flujo legal y de seguridad explicitamente implementado en backend y app.
- Cobertura documental interna alta.

### 10.2 Riesgos y brechas observadas

- Pruebas automatizadas limitadas (pocos tests visibles) frente al tamano de la plataforma.
- No se detecta pipeline CI activo en `.github/workflows`.
- `backend/index.php` escribe `debug_path.log` en runtime (posible ruido/performance/seguridad operacional).
- CORS abierto en varios endpoints (`*`), requiere endurecimiento por ambiente.
- Hay mezcla de codigo legacy y nuevas capas (algunas rutas/servicios duplicados), lo cual aumenta costo de mantenimiento.
- Potencial inconsistencia de estados de eliminacion de cuenta:
  - `delete-request.php` usa `inactive`.
  - `account_deletion_worker.php` procesa `pending_deletion`.
  - Esto puede impedir ejecucion final si no hay normalizacion externa.
- En `auth/verify_code.php` existe bypass por codigo fijo (`8052`) que deberia estar controlado estrictamente por ambiente o removido en produccion.

## 11) Conclusiones ejecutivas

- Viax ya opera como plataforma multirol de movilidad con logica avanzada de despacho, tracking, pricing y gobierno financiero.
- El backend concentra una logica de negocio madura y detallada, con foco en operacion en tiempo real.
- Flutter y web estan alineados al mismo dominio de negocio y exponen funcionalidades por rol coherentes.
- El proyecto se encuentra mas cerca de un producto operativo en crecimiento que de un prototipo.
- Para escalar con menor riesgo: fortalecer CI/testing, endurecer seguridad operacional y reducir deuda de componentes legacy.

## 12) Referencias internas directas usadas

- `README.md`
- `docs/QUE_TRATA_LA_APP_VIAX.md`
- `docs/REQUERIMIENTOS_FUNCIONALES_NO_FUNCIONALES.md`
- `docs/ESTIMACION_COSTOS_Y_VALORACION_EMPRESARIAL_VIAX.md`
- `docs/RIDE_ENGINE_ARCHITECTURE.md`
- `docs/DISPATCH_ENGINE_ARCHITECTURE.md`
- `docs/ARQUITECTURA_TRACKING_TIEMPO_REAL.md`
- `docs/ANEXO_INVENTARIO_ARCHIVOS.csv`
- Codigo fuente de `backend/`, `lib/`, `sitioweb/`

---

Si deseas, el siguiente paso puede ser generar un **anexo adicional en Markdown** con inventario literal por ruta (tabla grande) filtrado por:

1) solo backend propio,
2) solo Flutter propio,
3) solo web propio,

para tener tambien el listado textual completo en `.md` (ademas del CSV).

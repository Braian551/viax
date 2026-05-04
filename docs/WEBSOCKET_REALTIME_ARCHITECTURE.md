# Arquitectura WebSocket en Tiempo Real — Viax

## Resumen

Migración de polling/long-polling/SSE a WebSocket para reducir carga en PHP-FPM
y lograr latencia sub-500ms en actualizaciones de viaje.

## Flujo de Datos

```
┌──────────────┐      PUBLISH         ┌───────────────────┐      WS push        ┌──────────────┐
│  PHP Backend │  ───────────────────► │  Node.js Gateway  │  ──────────────────► │  Flutter App │
│  (endpoints) │   Redis viax:*       │  (uWebSockets.js) │   port 9100         │  (cliente)   │
└──────────────┘                      └───────────────────┘                      └──────────────┘
       │                                       │
       │  Redis SET/GET                        │  PSUBSCRIBE viax:*
       ▼                                       │  + legacy channels
  ┌─────────┐                                  │
  │  Redis  │◄─────────────────────────────────┘
  └─────────┘
```

## Componentes

### 1. Gateway WebSocket — `backend/realtime-gateway/`

- **Tecnología:** Node.js + uWebSockets.js (C++ nativo, ~10x más rápido que socket.io)
- **Puerto:** 9100
- **Autenticación:** Valida `user_session:{token}` en Redis (misma estructura que PHP)
- **Protocolo:** JSON sobre WebSocket binario

#### Archivos:
| Archivo | Rol |
|---------|-----|
| `src/server.js` | Servidor uWS, upgrade handler, message routing |
| `src/config.js` | Puerto, Redis, timeouts, rate limits |
| `src/auth.js` | Validación de token contra Redis |
| `src/redis-bridge.js` | PSUBSCRIBE a `viax:*`, mapeo de canales legacy |
| `src/connection-manager.js` | Gestión de sockets por canal |
| `src/metrics.js` | Contadores in-memory |
| `src/rate-limiter.js` | Sliding window por userId |
| `src/logger.js` | Logger por niveles |

#### Canales soportados:
```
user:{id}      — Eventos personales del usuario
driver:{id}    — Eventos del conductor (ofertas, asignaciones)
trip:{id}      — Estado de viaje, tracking, liquidación
request:{id}   — Estado de solicitud (búsqueda de conductor)
chat:{id}      — Mensajes de chat
```

### 2. Publicador PHP — `backend/services/RealtimeEventPublisher.php`

Clase estática que publica eventos al canal Redis `viax:*`.

```php
RealtimeEventPublisher::tripStatusChanged($tripId, $nuevoEstado, $userId, $driverId);
RealtimeEventPublisher::driverAssigned($requestId, $driverId, $clienteId, $tripId);
RealtimeEventPublisher::searchStatusChanged($requestId, $estado, $clienteId);
RealtimeEventPublisher::trackingUpdate($tripId, $trackingPayload);
RealtimeEventPublisher::newChatMessage($tripId, $messageData, $senderId, $receiverId);
RealtimeEventPublisher::tripOfferSent($requestId, $driverId, $offerPayload);
```

#### Formato de evento:
```json
{
  "type": "trip.status_changed",
  "version": 1,
  "entity": "trip",
  "entity_id": "42",
  "timestamp": 1719500000,
  "payload": { "status": "en_curso", ... }
}
```

#### Endpoints integrados:
- `conductor/update_trip_status.php`
- `conductor/accept_trip_request.php`
- `conductor/tracking/tracking_ingest_service.php`
- `workers/dispatch_worker.php`
- `chat/send_message.php`
- `user/cancel_trip_request.php`

### 3. Cliente Flutter — `lib/src/core/realtime/`

#### `websocket_manager.dart`
Singleton que gestiona la conexión WS con reconexión automática:
- Exponential backoff: 1s → 30s + jitter
- Heartbeat ping/pong: 25s/35s
- Buffer de mensajes (max 50) durante desconexión
- Re-suscripción automática al reconectar

#### `realtime_service.dart`
API de conveniencia para pantallas:
```dart
final sub = RealtimeService.instance.subscribeToTrip(tripId);
sub.stream.listen((event) { ... });
sub.cancel(); // al salir de la pantalla
```

### 4. Pantallas migradas

| Pantalla | Antes | Después |
|----------|-------|---------|
| `SearchingDriverScreen` | Polling 2s | WS + polling 10s safety-net |
| `UserActiveTripScreen` | Polling 5s + SSE | WS + polling 15s safety-net |
| `ConductorActiveTripScreen` | Polling 5s | WS + polling 15s safety-net |
| `ClientTripTrackingService` | SSE → polling 5s | WS → SSE → polling 15s |

## Despliegue

### Requisitos del servidor
- Node.js >= 18
- Redis (ya instalado)
- PM2 o Supervisor

### Instalación

```bash
cd /var/www/viax/backend/realtime-gateway
npm install --production
```

### Iniciar con PM2
```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup   # para auto-arranque
```

### Iniciar con Supervisor
```bash
cp infra/supervisor/viax-ws-gateway.conf /etc/supervisor/conf.d/
supervisorctl reread
supervisorctl update
supervisorctl start viax-ws-gateway
```

### Configurar Nginx (opcional, para proxy público)
```bash
cp infra/nginx/ws-gateway.conf /etc/nginx/conf.d/viax-ws.conf
nginx -t && systemctl reload nginx
```

### Verificar salud
```bash
curl http://127.0.0.1:9100/health
# {"status":"ok","uptime":...,"connections":0}

curl http://127.0.0.1:9100/metrics
# {"connections":{"current":0,...},...}
```

## Fallback y Resiliencia

La arquitectura funciona en cascada:

1. **WebSocket conectado** → Eventos push < 100ms, polling a 10-15s solo como verificación
2. **WS caído** → SSE automático (ClientTrackingService) + polling a 5s
3. **SSE y WS caídos** → Polling HTTP puro a 3-5s (igual que antes)

El usuario **nunca** pierde funcionalidad. Solo cambia la latencia.

## Métricas

El gateway expone `/metrics` con:
- `connections.current` — Conexiones activas
- `connections.total` — Total histórico
- `messages.received` / `messages.sent` — Conteo de mensajes
- `subscriptions.active` — Suscripciones activas
- `redis.events_received` — Eventos desde Redis
- `errors.total` — Errores acumulados

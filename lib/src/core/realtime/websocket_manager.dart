import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../../global/services/auth/user_service.dart';

/// Evento recibido del gateway WebSocket.
class RealtimeEvent {
  final String type;
  final int version;
  final String? entity;
  final String? entityId;
  final int timestamp;
  final Map<String, dynamic> payload;

  const RealtimeEvent({
    required this.type,
    this.version = 1,
    this.entity,
    this.entityId,
    required this.timestamp,
    required this.payload,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      type: json['type'] as String? ?? 'unknown',
      version: json['version'] as int? ?? 1,
      entity: json['entity'] as String?,
      entityId: json['entity_id']?.toString(),
      timestamp: json['timestamp'] as int? ?? 0,
      payload: json['payload'] as Map<String, dynamic>? ?? json,
    );
  }

  @override
  String toString() => 'RealtimeEvent($type, entity=$entity:$entityId)';
}

/// Estado de la conexión WebSocket.
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Singleton global de WebSocket para comunicación realtime con el gateway.
///
/// Características:
/// - Reconexión exponencial automática (1s → 30s + jitter)
/// - Buffer de mensajes durante desconexión
/// - Suscripción/desuscripción dinámica a canales
/// - Re-suscripción automática tras reconnect
/// - Heartbeat ping/pong para detección de conexión muerta
/// - Fallback automático a polling si WS no disponible
class WebSocketManager {
  // ─── Singleton ──────────────────────────────────────────────────
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  static WebSocketManager get instance => _instance;
  WebSocketManager._internal();

  // ─── Estado ─────────────────────────────────────────────────────
  WebSocket? _socket;
  WsConnectionState _state = WsConnectionState.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastPong;
  bool _disposed = false;
  bool _intentionalClose = false;

  // ─── Configuración ──────────────────────────────────────────────
  static const int _maxReconnectDelaySec = 30;
  static const int _heartbeatIntervalSec = 25;
  static const int _heartbeatTimeoutSec = 35;
  static const int _maxBufferedMessages = 50;

  // ─── Suscripciones activas ──────────────────────────────────────
  final Set<String> _subscriptions = {};
  final Map<String, Set<void Function(RealtimeEvent)>> _listeners = {};

  // ─── Buffer de mensajes pendientes (durante desconexión) ────────
  final List<String> _messageBuffer = [];

  // ─── Streams públicos ───────────────────────────────────────────
  final _stateController = StreamController<WsConnectionState>.broadcast();
  final _eventController = StreamController<RealtimeEvent>.broadcast();

  /// Stream del estado de conexión.
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  /// Stream global de TODOS los eventos recibidos.
  Stream<RealtimeEvent> get eventStream => _eventController.stream;

  /// Estado actual de la conexión.
  WsConnectionState get state => _state;

  /// Si hay conexión activa.
  bool get isConnected => _state == WsConnectionState.connected;

  // ─── Conexión ───────────────────────────────────────────────────

  /// Conecta al gateway WebSocket.
  /// Llama a esto al iniciar sesión o al detectar que hay viaje activo.
  Future<void> connect() async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }

    _disposed = false;
    _intentionalClose = false;
    _setState(WsConnectionState.connecting);

    try {
      final token = await _getAccessToken();
      if (token == null) {
        _log('No hay token de acceso, no se puede conectar');
        _setState(WsConnectionState.disconnected);
        return;
      }

      final wsUrl = _buildWsUrl(token);
      _log('Conectando a $wsUrl');

      _socket = await WebSocket.connect(
        wsUrl,
        headers: {'Origin': AppConfig.baseUrl},
      ).timeout(const Duration(seconds: 10));

      _socket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
      _resubscribeAll();
      _flushBuffer();

      _log('Conectado exitosamente');
    } catch (e) {
      _log('Error al conectar: $e');
      _setState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Desconecta intencionalmente (logout, etc).
  Future<void> disconnect() async {
    _intentionalClose = true;
    _disposed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    if (_socket != null) {
      try {
        await _socket!.close(WebSocketStatus.normalClosure, 'client_disconnect');
      } catch (_) {}
      _socket = null;
    }

    _subscriptions.clear();
    _listeners.clear();
    _messageBuffer.clear();
    _setState(WsConnectionState.disconnected);
    _log('Desconectado intencionalmente');
  }

  // ─── Suscripciones ─────────────────────────────────────────────

  /// Suscribe a un canal y registra un listener.
  /// Retorna función para cancelar la suscripción.
  VoidCallback subscribe(String channel, void Function(RealtimeEvent) onEvent) {
    _subscriptions.add(channel);
    _listeners.putIfAbsent(channel, () => {});
    _listeners[channel]!.add(onEvent);

    // Enviar suscripción al servidor si estamos conectados
    if (isConnected) {
      _send({'type': 'subscribe', 'payload': {'channel': channel}});
    }

    _log('Suscrito a $channel');

    // Retorna función de limpieza
    return () {
      _listeners[channel]?.remove(onEvent);
      if (_listeners[channel]?.isEmpty ?? true) {
        _listeners.remove(channel);
        _subscriptions.remove(channel);
        if (isConnected) {
          _send({'type': 'unsubscribe', 'payload': {'channel': channel}});
        }
      }
    };
  }

  /// Suscribe a un canal y retorna Stream de eventos.
  /// Más conveniente para uso con StreamBuilder.
  Stream<RealtimeEvent> channel(String channelName) {
    final controller = StreamController<RealtimeEvent>.broadcast();

    final unsub = subscribe(channelName, (event) {
      if (!controller.isClosed) {
        controller.add(event);
      }
    });

    controller.onCancel = () {
      unsub();
      controller.close();
    };

    return controller.stream;
  }

  /// Stream filtrado por tipo de evento.
  Stream<RealtimeEvent> on(String eventType) {
    return eventStream.where((e) => e.type == eventType);
  }

  // ─── Manejo de mensajes ─────────────────────────────────────────

  void _onMessage(dynamic data) {
    if (data is! String) return;

    Map<String, dynamic> json;
    try {
      json = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = json['type'] as String? ?? '';

    // Manejar mensajes de control
    switch (type) {
      case 'pong':
        _lastPong = DateTime.now();
        return;
      case 'connection.established':
        _log('Conexión confirmada por servidor');
        return;
      case 'subscribed':
        _log('Suscripción confirmada: ${json['payload']?['channel']}');
        return;
      case 'unsubscribed':
        return;
      case 'server.shutdown':
        _log('Servidor en shutdown, reconectando en ${json['payload']?['reconnect_delay_ms']}ms');
        return;
      case 'error':
        _log('Error del servidor: ${json['payload']?['message']}');
        return;
    }

    // Evento de negocio
    final event = RealtimeEvent.fromJson(json);
    _eventController.add(event);

    // Notificar a listeners de canales específicos
    final targetChannels = _resolveChannels(event);
    for (final ch in targetChannels) {
      final listeners = _listeners[ch];
      if (listeners != null) {
        for (final listener in listeners.toList()) {
          try {
            listener(event);
          } catch (e) {
            _log('Error en listener de $ch: $e');
          }
        }
      }
    }
  }

  /// Resuelve a qué canales locales corresponde un evento.
  List<String> _resolveChannels(RealtimeEvent event) {
    final channels = <String>[];
    if (event.entity != null && event.entityId != null) {
      channels.add('${event.entity}:${event.entityId}');
    }
    // Eventos dirigidos a user/driver por payload
    final p = event.payload;
    if (p['user_id'] != null) channels.add('user:${p['user_id']}');
    if (p['driver_id'] != null) channels.add('driver:${p['driver_id']}');
    if (p['trip_id'] != null) channels.add('trip:${p['trip_id']}');
    if (p['request_id'] != null) channels.add('request:${p['request_id']}');
    return channels.toSet().toList();
  }

  void _onError(Object error) {
    _log('Error WebSocket: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    _log('Conexión cerrada');
    _heartbeatTimer?.cancel();
    _socket = null;

    if (!_intentionalClose && !_disposed) {
      _setState(WsConnectionState.reconnecting);
      _scheduleReconnect();
    } else {
      _setState(WsConnectionState.disconnected);
    }
  }

  // ─── Heartbeat ──────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastPong = DateTime.now();

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatIntervalSec),
      (_) {
        if (!isConnected) return;

        // Verificar timeout del último pong
        if (_lastPong != null &&
            DateTime.now().difference(_lastPong!).inSeconds > _heartbeatTimeoutSec) {
          _log('Heartbeat timeout — reconectando');
          _socket?.close(WebSocketStatus.goingAway);
          return;
        }

        _send({'type': 'ping', 'payload': {}});
      },
    );
  }

  // ─── Reconexión exponencial ─────────────────────────────────────

  void _scheduleReconnect() {
    if (_disposed || _intentionalClose) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Backoff exponencial: 1, 2, 4, 8, 16, 30 (cap) + jitter
    final baseDelay = min(
      pow(2, _reconnectAttempts - 1).toInt(),
      _maxReconnectDelaySec,
    );
    final jitter = Random().nextInt(max(1, baseDelay ~/ 2));
    final delay = baseDelay + jitter;

    _log('Reconectando en ${delay}s (intento #$_reconnectAttempts)');
    _setState(WsConnectionState.reconnecting);

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (!_disposed && !_intentionalClose) {
        connect();
      }
    });
  }

  // ─── Re-suscripción tras reconnect ──────────────────────────────

  void _resubscribeAll() {
    for (final channel in _subscriptions) {
      _send({'type': 'subscribe', 'payload': {'channel': channel}});
    }
    if (_subscriptions.isNotEmpty) {
      _log('Re-suscrito a ${_subscriptions.length} canales');
    }
  }

  // ─── Buffer / envío ─────────────────────────────────────────────

  void _send(Map<String, dynamic> data) {
    final json = jsonEncode(data);
    if (isConnected && _socket != null) {
      try {
        _socket!.add(json);
      } catch (e) {
        _log('Error al enviar: $e');
        _bufferMessage(json);
      }
    } else {
      _bufferMessage(json);
    }
  }

  void _bufferMessage(String json) {
    if (_messageBuffer.length >= _maxBufferedMessages) {
      _messageBuffer.removeAt(0);
    }
    _messageBuffer.add(json);
  }

  void _flushBuffer() {
    if (_messageBuffer.isEmpty || !isConnected || _socket == null) return;
    final pending = List<String>.from(_messageBuffer);
    _messageBuffer.clear();
    for (final msg in pending) {
      try {
        _socket!.add(msg);
      } catch (e) {
        _log('Error al vaciar buffer: $e');
        break;
      }
    }
    if (pending.isNotEmpty) {
      _log('Buffer vaciado: ${pending.length} mensajes');
    }
  }

  // ─── Utilidades ─────────────────────────────────────────────────

  void _setState(WsConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  Future<String?> _getAccessToken() async {
    try {
      final session = await UserService.getSavedSession();
      return session?['access_token'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _buildWsUrl(String token) {
    final baseUrl = AppConfig.baseUrl;
    // Construir URL del WebSocket reemplazando http → ws
    // El gateway corre en el mismo host, puerto 9100
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final wsPort = const int.fromEnvironment('WS_PORT', defaultValue: 9100);
    return '$wsScheme://${uri.host}:$wsPort/ws?token=${Uri.encodeComponent(token)}';
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[WebSocketManager] $message');
    }
  }

  /// Libera recursos al cerrar la aplicación.
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.close();
    _stateController.close();
    _eventController.close();
  }
}

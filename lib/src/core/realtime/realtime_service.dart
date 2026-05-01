import 'dart:async';

import 'package:flutter/foundation.dart';

import 'websocket_manager.dart';
export 'websocket_manager.dart' show RealtimeEvent, WsConnectionState;

/// Servicio de conveniencia que combina WebSocket con fallback a polling.
///
/// Las pantallas usan esto en lugar de interactuar con WebSocketManager directamente.
/// Maneja la lógica de "si WebSocket no está disponible, usar polling".
class RealtimeService {
  // ─── Singleton ──────────────────────────────────────────────────
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  static RealtimeService get instance => _instance;
  RealtimeService._internal();

  final WebSocketManager _ws = WebSocketManager.instance;
  final bool _enabled = const bool.fromEnvironment(
    'REALTIME_ENABLED',
    defaultValue: true,
  );

  bool get isRealtimeEnabled => _enabled;

  /// Si el WebSocket está conectado y funcionando.
  bool get isWebSocketConnected => _ws.isConnected;

  /// Estado actual de la conexión.
  WsConnectionState get connectionState => _ws.state;

  /// Stream del estado de conexión.
  Stream<WsConnectionState> get stateStream => _ws.stateStream;

  /// Inicializa la conexión WebSocket.
  /// Llamar al iniciar sesión o cuando se necesita realtime.
  Future<void> initialize() async {
    if (!_enabled) return;
    await _ws.connect();
  }

  /// Desconecta WebSocket (logout).
  Future<void> shutdown() async {
    await _ws.disconnect();
  }

  /// Suscribe a eventos de una solicitud de viaje (búsqueda de conductor).
  ///
  /// Retorna [RealtimeSubscription] con cancel() y stream de eventos.
  RealtimeSubscription subscribeToRequest(int requestId) {
    return _subscribeToChannel('request:$requestId');
  }

  /// Suscribe a eventos de un viaje activo (tracking, estado).
  RealtimeSubscription subscribeToTrip(int tripId) {
    return _subscribeToChannel('trip:$tripId');
  }

  /// Suscribe a eventos del usuario (notificaciones personales).
  RealtimeSubscription subscribeToUser(int userId) {
    return _subscribeToChannel('user:$userId');
  }

  /// Suscribe a eventos del conductor.
  RealtimeSubscription subscribeToDriver(int driverId) {
    return _subscribeToChannel('driver:$driverId');
  }

  /// Suscribe al chat de un viaje.
  RealtimeSubscription subscribeToChat(int tripId) {
    return _subscribeToChannel('chat:$tripId');
  }

  RealtimeSubscription _subscribeToChannel(String channel) {
    final controller = StreamController<RealtimeEvent>.broadcast();
    VoidCallback? unsubscribe;

    if (_enabled) {
      unsubscribe = _ws.subscribe(channel, (event) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      });
    }

    // Si WS no está disponible, el stream queda vacío y el caller usa polling
    return RealtimeSubscription._(
      channel: channel,
      stream: controller.stream,
      cancel: () {
        unsubscribe?.call();
        if (!controller.isClosed) {
          controller.close();
        }
      },
      isWebSocketBacked: _enabled,
    );
  }
}

/// Suscripción a un canal realtime.
/// Contiene el stream de eventos y un método cancel() para limpiar.
class RealtimeSubscription {
  final String channel;
  final Stream<RealtimeEvent> stream;
  final VoidCallback _cancel;

  /// true si la suscripción está respaldada por WebSocket activo.
  /// false si no hay WS y se debe usar polling como fallback.
  final bool isWebSocketBacked;

  RealtimeSubscription._({
    required this.channel,
    required this.stream,
    required VoidCallback cancel,
    required this.isWebSocketBacked,
  }) : _cancel = cancel;

  void cancel() => _cancel();
}

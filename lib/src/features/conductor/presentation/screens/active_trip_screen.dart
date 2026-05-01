import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/core/network/connectivity_service.dart';
import 'package:viax/src/features/conductor/services/conductor_service.dart';
import 'package:viax/src/features/conductor/services/trip_tracking_service.dart';
import 'package:viax/src/global/widgets/chat/chat_widgets.dart';
import 'package:viax/src/global/widgets/trip_completion/trip_completion_widgets.dart';
import 'package:viax/src/global/services/rating_service.dart';
import 'package:viax/src/global/services/active_trip_navigation_service.dart';
import 'package:viax/src/core/offline/trip_command_executor.dart';
import 'package:viax/src/core/offline/trip_command_queue.dart';
import '../../../../global/services/chat_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../global/services/auth/user_service.dart';
import '../../../../global/services/local_notification_service.dart';
import '../widgets/active_trip/active_trip_widgets.dart';
import '../widgets/common/floating_button.dart';
import '../controllers/active_trip_controller.dart';
import 'package:viax/src/global/services/trip_persistence_service.dart';
import 'package:viax/src/global/services/global_map_holder.dart';
import 'package:viax/src/widgets/help/help_screen.dart';
import 'conductor_home_screen.dart';
import '../../../../core/realtime/realtime_service.dart';

/// Pantalla de viaje activo para el conductor.
///
/// Diseño estilo DiDi/Uber con mapa de navegación, panel inferior
/// deslizable y controles de acceso rápido.
class ConductorActiveTripScreen extends StatefulWidget {
  final int conductorId;
  final int? solicitudId;
  final int? viajeId;
  final int? clienteId;
  final double origenLat;
  final double origenLng;
  final double destinoLat;
  final double destinoLng;
  final String direccionOrigen;
  final String direccionDestino;
  final String? clienteNombre;
  final String? clienteFoto;
  final double? clienteCalificacion;
  final String? initialTripStatus; // NUEVO: Estado inicial del viaje

  const ConductorActiveTripScreen({
    super.key,
    required this.conductorId,
    this.solicitudId,
    this.viajeId,
    this.clienteId,
    required this.origenLat,
    required this.origenLng,
    required this.destinoLat,
    required this.destinoLng,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.clienteNombre,
    this.clienteFoto,
    this.clienteCalificacion,
    this.initialTripStatus,
  });

  @override
  State<ConductorActiveTripScreen> createState() =>
      _ConductorActiveTripScreenState();
}

class _ConductorActiveTripScreenState extends State<ConductorActiveTripScreen>
    with WidgetsBindingObserver {
  late final ActiveTripController _controller;
  static const double _pickupAutoArrivalMeters = 60.0;
  static const Duration _pickupAutoArrivalCooldown = Duration(seconds: 12);

  // Estado para mensajes flotantes
  String? _statusMessage;
  Color? _statusColor;
  Timer? _statusTimer;
  Timer? _pollingTimer; // Timer para polling
  DateTime? _tripStartTime; // Para calcular duración real
  DateTime _lastBackendUpdate = DateTime.now(); // Rate limiting para backend

  // Estados de carga para acciones (evitar doble tap y dar feedback)
  bool _isProcessingAction = false;
  String? _processingActionType; // 'arrived', 'start', 'finish', 'cancel'
  bool _pendingFinishSync = false;
  bool _isRetryingPendingFinish = false;
  bool _pendingCancelSync = false;
  bool _isRetryingPendingCancel = false;
  bool _serverCompletionHandled = false;
  TrackingFinalResult? _lastTrackingFinalResult;
  Map<String, dynamic>? _lastServerCompletedTrip;
  bool _autoArrivalTriggered = false;
  DateTime? _lastAutoArrivalAttempt;
  bool _wasOffline = false;
  VoidCallback? _connectivityListener;
  Timer? _pendingFinishRetryTimer;
  Timer? _pendingCancelRetryTimer;

  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<int>? _unreadSubscription;
  int _unreadCount = 0;
  final Set<int> _notifiedIncomingMessageIds = <int>{};
  bool _chatBootstrapCompleted = false;
  bool? _lastIsDark; // Para detectar cambios de tema
  late final String _mapOwnerKey;

  // WebSocket realtime
  RealtimeSubscription? _tripWsSub;
  RealtimeSubscription? _chatWsSub;
  StreamSubscription<RealtimeEvent>? _tripWsStreamSub;
  StreamSubscription<RealtimeEvent>? _chatWsStreamSub;
  bool _wsActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refuerza el estado visible para evitar falsos positivos del FAB flotante
    ActiveTripNavigationService().setOnTripScreen(true);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_lastIsDark != isDark) {
      _lastIsDark = isDark;
      // Si el mapa ya está listo, actualizar el estilo
      if (_controller.mapReady) {
        _triggerMapRenderRefresh();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _mapOwnerKey =
        'conductor_trip_map_${widget.solicitudId ?? widget.viajeId ?? widget.conductorId}';
    WidgetsBinding.instance.addObserver(this);
    if (widget.solicitudId != null && widget.clienteId != null) {
      ChatService.startPolling(
        solicitudId: widget.solicitudId!,
        usuarioId: widget.conductorId,
      );
      _setupChatListeners();
    }
    _initController();
    _checkRecovery();
    _setupRealtimeOrPolling();
    _registerActiveTripNavigation();
    _setupConnectivityStatusListener();
    // Solicitar permiso de overlay al iniciar el viaje
    _requestSystemOverlayPermission();
  }

  /// Configura WebSocket como fuente de eventos o cae a polling normal.
  void _setupRealtimeOrPolling() {
    final realtime = RealtimeService.instance;
    if (realtime.isRealtimeEnabled &&
        realtime.isWebSocketConnected &&
        widget.solicitudId != null) {
      _wsActive = true;
      debugPrint(
        '[ConductorTrip] WS conectado, suscribiendo trip:${widget.solicitudId}',
      );

      _tripWsSub = RealtimeService.instance.subscribeToTrip(
        widget.solicitudId!,
      );
      if (_tripWsSub != null && _tripWsSub!.isWebSocketBacked) {
        _tripWsStreamSub = _tripWsSub!.stream.listen(
          _onTripRealtimeEvent,
          onError: (_) => _wsActive = false,
          onDone: () => _wsActive = false,
        );
      }

      _chatWsSub = RealtimeService.instance.subscribeToChat(
        widget.solicitudId!,
      );
      if (_chatWsSub != null && _chatWsSub!.isWebSocketBacked) {
        _chatWsStreamSub = _chatWsSub!.stream.listen(
          _onChatRealtimeEvent,
          onError: (_) {},
        );
      }

      // Con WS activo no hay polling continuo (solo fallback real).
      unawaited(_checkTripStatus());
    } else {
      _startTripStatusPolling();
    }
  }

  void _onTripRealtimeEvent(RealtimeEvent event) {
    if (!mounted) return;
    debugPrint('[ConductorTrip] WS event: ${event.type}');
    if (event.type == 'trip.status_changed' || event.type == 'trip.cancelled') {
      _checkTripStatus();
    }
  }

  void _onChatRealtimeEvent(RealtimeEvent event) {
    if (!mounted) return;
    // Al recibir mensaje nuevo vía WS, reiniciar polling para forzar fetch inmediato.
    if ((event.type == 'chat.new_message' || event.type == 'chat.message') &&
        widget.solicitudId != null) {
      ChatService.startPolling(
        solicitudId: widget.solicitudId!,
        usuarioId: widget.conductorId,
      );
    }
  }

  void _setupConnectivityStatusListener() {
    final connectivity = ConnectivityService();
    _wasOffline = !connectivity.isOnline;

    _connectivityListener = () {
      final nowOnline = connectivity.isOnline;
      if (!nowOnline) {
        _wasOffline = true;
        _showStatus(
          'Sin conexión. Reintentando sincronización...',
          AppColors.warning,
        );
        return;
      }

      if (_wasOffline) {
        _wasOffline = false;
        _showStatus('Reconectado. Internet restablecido.', AppColors.success);
        if (_pendingFinishSync) {
          _showStatus(
            'Reconectado. Sincronizando finalización...',
            AppColors.warning,
          );
          unawaited(_retryPendingFinishWithoutTap());
        }
        if (_pendingCancelSync) {
          _showStatus(
            'Reconectado. Sincronizando cancelación...',
            AppColors.warning,
          );
          unawaited(_retryPendingCancelWithoutTap());
        }
      }
    };

    connectivity.isOnlineListenable.addListener(_connectivityListener!);
  }

  /// Solicita permiso para el overlay del sistema
  Future<void> _requestSystemOverlayPermission() async {
    // Esperamos un poco para que la UI se estabilice
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final hasPermission = await ActiveTripNavigationService()
        .hasSystemOverlayPermission();
    if (!hasPermission && mounted) {
      await ActiveTripNavigationService().requestSystemOverlayPermission(
        context,
      );
    }
  }

  /// Registra este viaje en el servicio de navegación global
  void _registerActiveTripNavigation() {
    if (widget.solicitudId == null) return;

    ActiveTripNavigationService().registerActiveTrip(
      ActiveTripData(
        solicitudId: widget.solicitudId!,
        userId: widget.conductorId,
        userRole: 'conductor',
        origenLat: widget.origenLat,
        origenLng: widget.origenLng,
        direccionOrigen: widget.direccionOrigen,
        destinoLat: widget.destinoLat,
        destinoLng: widget.destinoLng,
        direccionDestino: widget.direccionDestino,
        clienteNombre: widget.clienteNombre,
        clienteFoto: widget.clienteFoto,
        clienteInfo: widget.clienteId != null
            ? {
                'id': widget.clienteId,
                if (widget.clienteCalificacion != null)
                  'calificacion': widget.clienteCalificacion,
              }
            : null,
        initialTripStatus: widget.initialTripStatus,
      ),
    );

    // Asegura estado consistente por si hubo cambios de ruta/lifecycle.
    ActiveTripNavigationService().setOnTripScreen(true);
  }

  void _startTripStatusPolling() {
    // Polling cada 5 segundos para verificar estado
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkTripStatus();
    });

    // Primer chequeo inmediato para no esperar el primer tick.
    unawaited(_checkTripStatus());
  }

  Future<void> _checkTripStatus() async {
    if (widget.solicitudId == null || !mounted) return;
    try {
      // Si hay finalización pendiente por red, reintentar flush en cada ciclo.
      if (_pendingFinishSync) {
        await _retryPendingFinishWithoutTap();
      }
      if (_pendingCancelSync) {
        await _retryPendingCancelWithoutTap();
      }

      final tripData = await ConductorService.checkTripStatus(
        widget.solicitudId!,
      );

      if (tripData != null && mounted) {
        final estado = (tripData['estado'] as String?)?.toLowerCase();

        // Si el usuario canceló
        if (estado == 'cancelada' || estado == 'cancelada_por_usuario') {
          _pollingTimer?.cancel();
          if (_pendingCancelSync) {
            _completePendingCancelAndNavigate();
          } else {
            _handleUserCancellation();
          }
          return;
        }

        // Si el backend ya marcó completado, cerrar flujo automáticamente.
        final isCompleted =
            estado == 'completada' ||
            estado == 'completado' ||
            estado == 'finalizada' ||
            estado == 'finalizado' ||
            estado == 'completed';

        if (isCompleted && !_serverCompletionHandled) {
          if (!_tripHasCanonicalSettlement(tripData)) {
            _showStatus(
              'Finalizando liquidación en servidor...',
              AppColors.warning,
            );
            return;
          }

          _lastServerCompletedTrip = tripData;
          _serverCompletionHandled = true;
          _pollingTimer?.cancel();
          await TripPersistenceService().clearActiveTrip();
          ActiveTripNavigationService().clearActiveTrip();

          if (!mounted) return;
          _showStatus(
            'Finalización confirmada por servidor',
            AppColors.success,
          );
          _navigateToTripCompletion(
            trackingResult: _lastTrackingFinalResult,
            serverTripData: tripData,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [TripStatus] Error consultando estado: $e');
    }
  }

  bool _tripHasCanonicalSettlement(Map<String, dynamic> tripData) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final fixedPrice = toDouble(tripData['precio_fijo']);
    final canonicalPrice = toDouble(tripData['price_final_canonical']);
    final finalPrice = toDouble(tripData['precio_final']);
    final metricsLocked =
        tripData['metrics_locked'] == true || tripData['finalized_at'] != null;
    return (fixedPrice != null && fixedPrice > 0) ||
        (canonicalPrice != null && canonicalPrice > 0) ||
        (finalPrice != null && finalPrice > 0) ||
        metricsLocked;
  }

  Future<Map<String, dynamic>?> _awaitCanonicalCompletedTrip({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (widget.solicitudId == null) return null;

    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      final tripData = await ConductorService.checkTripStatus(
        widget.solicitudId!,
      );
      if (tripData != null) {
        final estado = (tripData['estado'] as String?)?.toLowerCase();
        final isCompleted =
            estado == 'completada' ||
            estado == 'completado' ||
            estado == 'finalizada' ||
            estado == 'finalizado' ||
            estado == 'completed';

        if (isCompleted && _tripHasCanonicalSettlement(tripData)) {
          return tripData;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    return null;
  }

  bool _isTripCancelledState(String? estado) {
    return estado == 'cancelada' || estado == 'cancelada_por_usuario';
  }

  Future<bool> _hasPendingCommandForTrip(TripCommandType type) async {
    if (widget.solicitudId == null) return false;

    final pending = await TripCommandQueue.instance.getPendingCommands();
    return pending.any(
      (cmd) =>
          cmd.tripId == widget.solicitudId && cmd.commandType == type.wireValue,
    );
  }

  Future<void> _retryPendingFinishWithoutTap() async {
    if (widget.solicitudId == null || _isRetryingPendingFinish) return;
    if (!ConnectivityService().isOnline) return;

    _isRetryingPendingFinish = true;

    try {
      final pendingBefore = await TripCommandQueue.instance
          .getPendingCommands();
      final hasPendingFinishBefore = pendingBefore.any(
        (cmd) =>
            cmd.tripId == widget.solicitudId &&
            cmd.commandType == TripCommandType.finishTrip.wireValue,
      );

      if (!hasPendingFinishBefore) {
        if (_pendingFinishSync && mounted) {
          setState(() {
            _pendingFinishSync = false;
          });
        } else {
          _pendingFinishSync = false;
        }
        _stopPendingFinishRetry();
        return;
      }

      await TripCommandExecutor.instance.flushQueue();

      final pendingAfter = await TripCommandQueue.instance.getPendingCommands();
      final hasPendingFinishAfter = pendingAfter.any(
        (cmd) =>
            cmd.tripId == widget.solicitudId &&
            cmd.commandType == TripCommandType.finishTrip.wireValue,
      );

      if (!hasPendingFinishAfter && mounted) {
        setState(() {
          _pendingFinishSync = false;
        });
        _stopPendingFinishRetry();
        _showStatus(
          'Finalización sincronizada. Confirmando estado...',
          AppColors.success,
        );
        unawaited(_checkTripStatus());
      }
    } catch (e) {
      debugPrint('⚠️ [TripFinalize] Reintento pendiente falló: $e');
    } finally {
      _isRetryingPendingFinish = false;
    }
  }

  Future<void> _retryPendingCancelWithoutTap() async {
    if (widget.solicitudId == null || _isRetryingPendingCancel) return;
    if (!ConnectivityService().isOnline) return;

    _isRetryingPendingCancel = true;

    try {
      final hasPendingCancelBefore = await _hasPendingCommandForTrip(
        TripCommandType.cancelTrip,
      );

      if (!hasPendingCancelBefore) {
        final tripData = await ConductorService.checkTripStatus(
          widget.solicitudId!,
        );
        final estado = (tripData?['estado'] as String?)?.toLowerCase();

        if (_isTripCancelledState(estado)) {
          _completePendingCancelAndNavigate();
          return;
        }

        if (mounted) {
          setState(() {
            _pendingCancelSync = false;
            _isProcessingAction = false;
            _processingActionType = null;
          });
        } else {
          _pendingCancelSync = false;
          _isProcessingAction = false;
          _processingActionType = null;
        }

        _stopPendingCancelRetry();
        _showStatus(
          'No se pudo confirmar la cancelación. Intenta nuevamente.',
          AppColors.warning,
        );
        return;
      }

      await TripCommandExecutor.instance.flushQueue();

      final hasPendingCancelAfter = await _hasPendingCommandForTrip(
        TripCommandType.cancelTrip,
      );

      if (!hasPendingCancelAfter) {
        final tripData = await ConductorService.checkTripStatus(
          widget.solicitudId!,
        );
        final estado = (tripData?['estado'] as String?)?.toLowerCase();

        if (_isTripCancelledState(estado)) {
          _completePendingCancelAndNavigate();
          return;
        }

        _showStatus(
          'Cancelación enviada. Confirmando estado del viaje...',
          AppColors.warning,
        );
        unawaited(_checkTripStatus());
      }
    } catch (e) {
      debugPrint('⚠️ [TripCancel] Reintento pendiente falló: $e');
    } finally {
      _isRetryingPendingCancel = false;
    }
  }

  void _startPendingFinishRetry() {
    _pendingFinishRetryTimer?.cancel();
    _pendingFinishRetryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_pendingFinishSync || !mounted) {
        _stopPendingFinishRetry();
        return;
      }
      if (!ConnectivityService().isOnline) {
        return;
      }
      unawaited(_retryPendingFinishWithoutTap());
    });
  }

  void _stopPendingFinishRetry() {
    _pendingFinishRetryTimer?.cancel();
    _pendingFinishRetryTimer = null;
  }

  void _startPendingCancelRetry() {
    _pendingCancelRetryTimer?.cancel();
    _pendingCancelRetryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_pendingCancelSync || !mounted) {
        _stopPendingCancelRetry();
        return;
      }
      if (!ConnectivityService().isOnline) {
        return;
      }
      unawaited(_retryPendingCancelWithoutTap());
    });
  }

  void _stopPendingCancelRetry() {
    _pendingCancelRetryTimer?.cancel();
    _pendingCancelRetryTimer = null;
  }

  void _completePendingCancelAndNavigate() {
    if (!mounted) return;

    setState(() {
      _pendingCancelSync = false;
      _isProcessingAction = false;
      _processingActionType = null;
    });
    _stopPendingCancelRetry();

    TripTrackingService().stopTracking();
    TripPersistenceService().clearActiveTrip();
    ActiveTripNavigationService().clearActiveTrip();

    _showStatus(
      'Cancelación sincronizada. Cerrando viaje...',
      AppColors.success,
    );
    unawaited(_navigateToHome());
  }

  void _handleUserCancellation() {
    if (!mounted) return;

    _stopPendingCancelRetry();

    // Detener tracking
    TripTrackingService().stopTracking();
    TripPersistenceService().clearActiveTrip();
    ActiveTripNavigationService().clearActiveTrip();

    // Reproducir sonido de cancelación si existe
    // SoundService.playCancelSound();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Viaje cancelado'),
        content: const Text('El usuario ha cancelado el viaje.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo
              _navigateToHome(); // Ir al home
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToHome() async {
    final session = await UserService.getSavedSession();

    if (!mounted) return;

    if (session != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorHomeScreen(conductorUser: session),
        ),
        (route) => false,
      );
    } else {
      // Si no hay sesión (muy raro), volver al inicio de la app
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  Future<void> _checkRecovery() async {
    final savedTrip = await TripPersistenceService().getActiveTrip();
    if (savedTrip != null && savedTrip.tripId == widget.solicitudId) {
      setState(() {
        _tripStartTime = savedTrip.startTime;
      });
      _controller.restoreState(savedTrip.accumulatedDistance);
      debugPrint('🔄 Viaje recuperado en pantalla activa');
    }
  }

  void _initController() {
    _controller = ActiveTripController(
      origenLat: widget.origenLat,
      origenLng: widget.origenLng,
      destinoLat: widget.destinoLat,
      destinoLng: widget.destinoLng,
      onStateChanged: _onControllerStateChanged,
    );

    // Configurar estado inicial según el status del backend
    final normalizedStatus = (widget.initialTripStatus ?? '').toLowerCase();

    if (normalizedStatus == 'conductor_llego' ||
        normalizedStatus == 'driver_arrived') {
      _controller.toPickup = false;
      _controller.arrivedAtPickup = true;
    } else if (normalizedStatus == 'en_curso' ||
        normalizedStatus == 'recogido' ||
        normalizedStatus == 'picked_up' ||
        normalizedStatus == 'in_progress') {
      _controller.toPickup = false;
      _controller.arrivedAtPickup = false;
      // Asegurar que comience el tracking real si no se ha hecho
      if (widget.solicitudId != null) {
        // Pequeño delay para asegurar que el controller esté listo
        Future.delayed(Duration.zero, () {
          if (mounted) {
            _controller.startRealTimeTracking(
              solicitudId: widget.solicitudId!,
              conductorId: widget.conductorId,
              startTime:
                  _tripStartTime, // Si recuperamos persistencia, usar ese tiempo
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Notificar que salimos de la pantalla de viaje
    ActiveTripNavigationService().setOnTripScreen(false);
    if (_connectivityListener != null) {
      ConnectivityService().isOnlineListenable.removeListener(
        _connectivityListener!,
      );
      _connectivityListener = null;
    }
    _stopPendingFinishRetry();
    _stopPendingCancelRetry();
    GlobalMapHolder.invalidate(ownerKey: _mapOwnerKey);
    _controller.dispose();
    // Limpiar suscripciones WebSocket
    _tripWsStreamSub?.cancel();
    _chatWsStreamSub?.cancel();
    _tripWsSub?.cancel();
    _chatWsSub?.cancel();
    _messagesSubscription?.cancel();
    _unreadSubscription?.cancel();
    ChatService.stopPolling();
    _pollingTimer?.cancel(); // Cancelar polling
    super.dispose();
  }

  void _setupChatListeners() {
    // Escuchar mensajes nuevos
    _messagesSubscription = ChatService.messagesStream.listen((messages) {
      if (messages.isEmpty) return;

      if (!_chatBootstrapCompleted) {
        _chatBootstrapCompleted = true;
        for (final message in messages) {
          if (message.remitenteId != widget.conductorId) {
            _notifiedIncomingMessageIds.add(message.id);
          }
        }
        return;
      }

      // Si el chat está abierto, no hacer nada
      if (ChatService.isChatOpen) return;

      final incomingMessages = messages
          .where(
            (message) =>
                message.remitenteId != widget.conductorId &&
                !_notifiedIncomingMessageIds.contains(message.id),
          )
          .toList();

      if (incomingMessages.isEmpty) return;

      if (mounted) {
        setState(() {
          _unreadCount += incomingMessages.length;
        });
      }

      for (final message in incomingMessages) {
        _notifiedIncomingMessageIds.add(message.id);

        // Reproducir sonido de mensaje
        SoundService.playMessageSound();

        LocalNotificationService.showMessageNotification(
          title: message.remitenteNombre ?? 'Cliente',
          body: message.mensaje,
          solicitudId: widget.solicitudId,
          notificationId: message.id,
        );
      }
    });

    // Escuchar clics en notificaciones
    LocalNotificationService.onNotificationClick.listen((payload) {
      if (payload != null && int.tryParse(payload) == widget.solicitudId) {
        // Navegar al chat si estamos en la misma solicitud
        // Verificar si el chat ya está abierto para no abrirlo doble
        if (!ChatService.isChatOpen && mounted) {
          _openChat();
        }
      }
    });

    // Escuchar conteo de no leídos
    _unreadSubscription = ChatService.unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          if (ChatService.isChatOpen) {
            _unreadCount = count;
          } else if (count > _unreadCount) {
            _unreadCount = count;
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.positionStream?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller.positionStream?.resume();
      ActiveTripNavigationService().setOnTripScreen(true);
    }
  }

  void _onControllerStateChanged() {
    if (mounted && !_controller.isDisposed) {
      setState(() {});
      _maybeAutoMarkArrivedPickup();
      _checkAndSyncBackend();
    }
  }

  void _maybeAutoMarkArrivedPickup() {
    if (!mounted || _controller.isDisposed) return;
    if (_autoArrivalTriggered) return;
    if (_isProcessingAction) return;
    if (widget.solicitudId == null) return;
    if (!_controller.toPickup || _controller.arrivedAtPickup) return;

    final driver = _controller.driverLocation;
    if (driver == null) return;

    final meters = _controller.calculateDistance(driver, _controller.pickup);
    if (meters > _pickupAutoArrivalMeters) return;

    final now = DateTime.now();
    if (_lastAutoArrivalAttempt != null &&
        now.difference(_lastAutoArrivalAttempt!) < _pickupAutoArrivalCooldown) {
      return;
    }
    _lastAutoArrivalAttempt = now;

    debugPrint(
      '📍 [ConductorActiveTrip] Auto llegada detectada a ${meters.toStringAsFixed(1)}m del pickup',
    );

    unawaited(() async {
      try {
        await _onArrivedPickup();
        if (mounted) {
          _autoArrivalTriggered = true;
        }
      } catch (e) {
        debugPrint('⚠️ [ConductorActiveTrip] Auto llegada falló: $e');
      }
    }());
  }

  /// Sincroniza la ubicación y datos del viaje con el backend con throttling
  void _checkAndSyncBackend() {
    if (_controller.driverLocation == null) return;

    final now = DateTime.now();
    if (now.difference(_lastBackendUpdate).inSeconds < 10) return;

    _lastBackendUpdate = now;

    // Preparar datos
    final lat = _controller.driverLocation!.coordinates.lat.toDouble();
    final lng = _controller.driverLocation!.coordinates.lng.toDouble();
    double? distance;
    int? elapsed;

    // Si el viaje está en curso (llevando al pasajero)
    if (!_controller.toPickup &&
        !_controller.arrivedAtPickup &&
        _tripStartTime != null) {
      distance = _controller.distanceKm;
      elapsed = now.difference(_tripStartTime!).inMinutes;
    }

    // Enviar al backend (fire and forget)
    ConductorService.actualizarUbicacion(
      conductorId: widget.conductorId,
      latitud: lat,
      longitud: lng,
      distanceKm: distance,
      elapsedMinutes: elapsed,
      solicitudId: widget.solicitudId,
    ).then((success) {
      if (!success) {
        debugPrint('⚠️ Falló actualización de ubicación al backend');
      }
    });
  }

  // ===========================================================================
  // ACCIONES
  // ===========================================================================

  /// Notifica al backend que el conductor llegó al punto de recogida.
  Future<void> _onArrivedPickup() async {
    // Prevenir doble tap
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
      _processingActionType = 'arrived';
    });

    if (widget.solicitudId != null) {
      final arrivedResult = await TripCommandExecutor.instance.enqueueAndTryNow(
        tripId: widget.solicitudId!,
        type: TripCommandType.driverArrived,
        payload: <String, dynamic>{
          'conductor_id': widget.conductorId,
          'solicitud_id': widget.solicitudId,
          'nuevo_estado': 'conductor_llego',
        },
      );

      if (!arrivedResult.success) {
        setState(() {
          _isProcessingAction = false;
          _processingActionType = null;
        });
        _showStatus(
          arrivedResult.pending
              ? 'No se pudo confirmar llegada. Reintenta al recuperar conexión.'
              : 'Error al confirmar llegada. Intenta nuevamente.',
          AppColors.warning,
        );
        return;
      }
    }

    await _controller.onArrivedPickup();
    if (!mounted || _controller.isDisposed) return;

    _autoArrivalTriggered = true;

    setState(() {
      _isProcessingAction = false;
      _processingActionType = null;
    });

    _showStatus('¡Llegaste al punto! Espera al pasajero', AppColors.accent);
  }

  /// Inicia el viaje cuando el cliente se sube al vehículo.
  Future<void> _onStartTrip() async {
    // Prevenir doble tap
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
      _processingActionType = 'start';
    });

    if (widget.solicitudId != null) {
      final startResult = await TripCommandExecutor.instance.enqueueAndTryNow(
        tripId: widget.solicitudId!,
        type: TripCommandType.startTrip,
        payload: <String, dynamic>{
          'conductor_id': widget.conductorId,
          'solicitud_id': widget.solicitudId,
          'nuevo_estado': 'recogido',
        },
      );

      if (!startResult.success) {
        setState(() {
          _isProcessingAction = false;
          _processingActionType = null;
        });
        _showStatus(
          startResult.pending
              ? 'Inicio pendiente por conexión. Reintenta en unos segundos.'
              : 'Error al iniciar el viaje. Intenta nuevamente.',
          AppColors.warning,
        );
        return;
      }
    }

    await _controller.onStartTrip();
    if (!mounted || _controller.isDisposed) return;

    _autoArrivalTriggered = false;

    // Registrar tiempo de inicio - ESTE ES EL CRONÓMETRO OFICIAL
    _tripStartTime = DateTime.now();

    // Iniciar tracking en tiempo real - SINCRONIZADO con el cronómetro
    // El mismo _tripStartTime se usa para tracking y para el cálculo final
    if (widget.solicitudId != null) {
      await _controller.startRealTimeTracking(
        solicitudId: widget.solicitudId!,
        conductorId: widget.conductorId,
        startTime: _tripStartTime, // Sincronizar con cronómetro del conductor
      );
    }

    setState(() {
      _isProcessingAction = false;
      _processingActionType = null;
    });

    _showStatus('¡Viaje iniciado! Navegando al destino', AppColors.success);
  }

  /// Finaliza el viaje cuando se llega al destino.
  Future<void> _onFinishTrip() async {
    // Prevenir doble tap - CRÍTICO para evitar múltiples finalizaciones
    if (_isProcessingAction) {
      debugPrint('⚠️ Ignorando tap duplicado - acción en progreso');
      return;
    }

    setState(() {
      _isProcessingAction = true;
      _processingActionType = 'finish';
    });

    _showStatus('Finalizando viaje...', AppColors.warning);

    // ========== CALCULAR TIEMPO REAL DEL CRONÓMETRO ==========
    // El tiempo se mide desde "comenzar viaje" hasta "finalizar viaje"
    // Este es el tiempo REAL que el conductor usó para el viaje
    final tiempoRealSeg = _tripStartTime != null
        ? DateTime.now().difference(_tripStartTime!).inSeconds
        : 0;

    debugPrint(
      '⏱️ [Conductor] Tiempo real cronómetro: ${tiempoRealSeg}s (${(tiempoRealSeg / 60).toStringAsFixed(2)} min)',
    );

    // Finalizar tracking y obtener precio real - enviando el tiempo del cronómetro
    final trackingResult = await _controller.finalizeTracking(
      tiempoRealSegundos: tiempoRealSeg,
    );
    _lastTrackingFinalResult = trackingResult;

    // Usar datos del tracking - distancia REAL recorrida (NO la estimada)
    // Si no hay tracking, usar 0 (no se movió)
    final distanciaKm =
        trackingResult?.distanciaRealKm ??
        (_controller.distanciaRecorridaKm > 0
            ? _controller.distanciaRecorridaKm
            : 0.0);

    // Usar el tiempo del cronómetro (ya se envió al backend)
    final duracionMin = (tiempoRealSeg / 60).ceil();

    if (widget.solicitudId != null) {
      final finalizeStartedAt = DateTime.now();

      final payload = <String, dynamic>{
        'conductor_id': widget.conductorId,
        'solicitud_id': widget.solicitudId,
        'nuevo_estado': 'completada',
        'trip_state': 'completed',
        'distancia_recorrida': distanciaKm,
        'tiempo_transcurrido': duracionMin,
      };

      final finalizeResult = await TripCommandExecutor.instance
          .enqueueAndTryNow(
            tripId: widget.solicitudId!,
            type: TripCommandType.finishTrip,
            payload: payload,
          );

      final finalizeLatency = DateTime.now()
          .difference(finalizeStartedAt)
          .inMilliseconds;
      debugPrint(
        '[TripFinalize] ts=${DateTime.now().toIso8601String()} tripId=${widget.solicitudId} '
        'latency_ms=$finalizeLatency result=${finalizeResult.success ? 'confirmed' : (finalizeResult.pending ? 'pending_retry' : 'failed')}',
      );

      if (!finalizeResult.success) {
        if (!mounted) return;
        setState(() {
          _isProcessingAction = false;
          _processingActionType = null;
          _pendingFinishSync = finalizeResult.pending;
        });

        if (finalizeResult.pending) {
          _startPendingFinishRetry();
        }

        _showStatus(
          finalizeResult.pending
              ? 'Sin conexión estable. Se reintentará automáticamente al reconectar.'
              : 'Error al confirmar finalización. Intenta nuevamente.',
          AppColors.warning,
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isProcessingAction = false;
      _processingActionType = null;
      _pendingFinishSync = false;
    });
    _stopPendingFinishRetry();

    final canonicalTrip = await _awaitCanonicalCompletedTrip();
    if (canonicalTrip != null) {
      _lastServerCompletedTrip = canonicalTrip;
    }

    if (!mounted) return;

    if (canonicalTrip == null) {
      _showStatus(
        'Viaje finalizado. Esperando liquidación final del servidor...',
        AppColors.warning,
      );
      return;
    }

    // Navegar a pantalla de completación con datos del tracking
    _navigateToTripCompletion(
      trackingResult: trackingResult,
      serverTripData: canonicalTrip,
    );
  }

  /// Navega a la pantalla de completación del viaje.
  void _navigateToTripCompletion({
    TrackingFinalResult? trackingResult,
    Map<String, dynamic>? serverTripData,
  }) {
    final authoritativeTrip = serverTripData ?? _lastServerCompletedTrip;

    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final normalized = v.trim().toLowerCase();
        return normalized == '1' ||
            normalized == 'true' ||
            normalized == 'yes' ||
            normalized == 'si';
      }
      return false;
    }

    Map<String, dynamic>? extractBreakdown(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // Limpiar persistencia justo al navegar al resumen final.
    TripPersistenceService().clearActiveTrip();
    ActiveTripNavigationService().clearActiveTrip();

    final canonicalDistance =
        toDouble(authoritativeTrip?['distance_final']) ??
        toDouble(authoritativeTrip?['distancia_recorrida']);
    final canonicalDuration =
        toInt(authoritativeTrip?['duration_final']) ??
        toInt(authoritativeTrip?['duracion_segundos']) ??
        toInt(authoritativeTrip?['tiempo_transcurrido_seg']);
    final canonicalPrice =
        toDouble(authoritativeTrip?['price_final_canonical']) ??
        toDouble(authoritativeTrip?['precio_final']);
    final fixedPrice =
        toDouble(authoritativeTrip?['precio_fijo']) ??
        toDouble(authoritativeTrip?['precio_estimado']) ??
        canonicalPrice;
    final canonicalBreakdown = extractBreakdown(
      authoritativeTrip?['desglose_precio'],
    );
    final breakdownFinalPrice = toDouble(canonicalBreakdown?['precio_final']);
    final estimatedDistance =
        toDouble(authoritativeTrip?['distancia_estimada']) ?? 0.0;
    final estimatedMinutes =
        toInt(authoritativeTrip?['tiempo_estimado_min']) ??
        toInt(authoritativeTrip?['tiempo_estimado']) ??
        0;

    // Usar datos del tracking - distancia REAL recorrida (NO la estimada)
    final realDistanceKm =
        canonicalDistance ??
        trackingResult?.distanciaRealKm ??
        (_controller.distanciaRecorridaKm > 0
            ? _controller.distanciaRecorridaKm
            : 0.0);

    // ========== TIEMPO DEL CRONÓMETRO DEL CONDUCTOR ==========
    // El tiempo se envió al backend y vuelve en trackingResult.tiempoRealSeg
    // Este es el tiempo REAL medido desde "comenzar viaje" hasta "finalizar"
    int realDurationSeg;
    if (canonicalDuration != null && canonicalDuration > 0) {
      realDurationSeg = canonicalDuration;
    } else if (trackingResult != null && trackingResult.tiempoRealSeg > 0) {
      // Tiempo del cronómetro del conductor (el más preciso)
      realDurationSeg = trackingResult.tiempoRealSeg;
    } else if (_tripStartTime != null) {
      // Fallback: calcular localmente
      realDurationSeg = DateTime.now().difference(_tripStartTime!).inSeconds;
    } else {
      realDurationSeg = 0;
    }

    final trackingValido =
        toBool(authoritativeTrip?['tracking_valido']) ||
        (realDistanceKm > 0.1 && realDurationSeg > 30);

    final distanciaKm = trackingValido ? realDistanceKm : estimatedDistance;
    final duracionSeg = trackingValido
        ? realDurationSeg
        : (estimatedMinutes > 0 ? estimatedMinutes * 60 : realDurationSeg);
    final precio = canonicalPrice ?? breakdownFinalPrice ?? fixedPrice ?? 0.0;

    final resumenCalculo = trackingValido
        ? 'Precio final confirmado. Métricas reales validadas para el resumen del viaje.'
        : 'Precio final confirmado. Se mostraron métricas estimadas porque el tracking real fue insuficiente.';

    debugPrint('📊 [ConductorTracking] Finalizando viaje:');
    debugPrint('   - Precio final mostrado: $precio');
    debugPrint('   - Tracking válido: $trackingValido');
    debugPrint('   - Distancia mostrada: $distanciaKm km');
    debugPrint(
      '   - Tiempo mostrado: ${duracionSeg}s (${(duracionSeg / 60).toStringAsFixed(1)} min)',
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TripCompletionScreen(
          userType: TripCompletionUserType.conductor,
          tripData: TripCompletionData(
            solicitudId: widget.solicitudId ?? 0,
            origen: widget.direccionOrigen,
            destino: widget.direccionDestino,
            distanciaKm: distanciaKm,
            duracionSegundos: duracionSeg,
            precio: precio,
            metodoPago: 'Efectivo', // TODO: Obtener del backend
            resumenCalculo: resumenCalculo,
            desglosePrecio: canonicalBreakdown ?? trackingResult?.desglose,
            otroUsuarioNombre: widget.clienteNombre ?? 'Pasajero',
            otroUsuarioFoto: widget.clienteFoto,
          ),
          miUsuarioId: widget.conductorId,
          otroUsuarioId: widget.clienteId ?? 0,
          onSubmitRating: (rating, comentario) async {
            if (widget.clienteId == null) {
              return {'success': false, 'message': 'Cliente no disponible'};
            }
            final result = await RatingService.enviarCalificacion(
              solicitudId: widget.solicitudId ?? 0,
              calificadorId: widget.conductorId,
              calificadoId: widget.clienteId!,
              calificacion: rating,
              tipoCalificador: 'conductor',
              comentario: comentario,
            );
            return result;
          },
          onConfirmPayment: (received) async {
            if (!received) return false;
            final result = await RatingService.confirmarPagoEfectivo(
              solicitudId: widget.solicitudId ?? 0,
              conductorId: widget.conductorId,
              monto: precio,
            );
            return result['success'] == true;
          },
          onComplete: () {
            // Volver a la pantalla principal del conductor
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
    );
  }

  void _showStatus(String message, Color color) {
    _statusTimer?.cancel();
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
    HapticFeedback.mediumImpact();
    // Ocultar automáticamente después de 4 segundos
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }

  /// Abrir pantalla de chat con el cliente
  void _openChat() {
    debugPrint('🔍 [Chat] Intentando abrir chat...');
    debugPrint('   solicitudId: ${widget.solicitudId}');
    debugPrint('   clienteId: ${widget.clienteId}');
    debugPrint('   conductorId: ${widget.conductorId}');

    if (widget.solicitudId == null) {
      debugPrint('❌ [Chat] No hay solicitudId');
      _showStatus('No hay información del viaje', AppColors.error);
      return;
    }

    final clienteIdToUse = widget.clienteId;

    if (clienteIdToUse == null) {
      debugPrint(
        '⚠️ [Chat] clienteId es null, mostrando diálogo de información',
      );
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chat no disponible'),
          content: const Text(
            'La información del cliente no está disponible en este momento. '
            'Por favor, intenta recargar el viaje o contacta soporte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    debugPrint('✅ [Chat] Navegando a ChatScreen...');

    try {
      setState(() => _unreadCount = 0);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            solicitudId: widget.solicitudId!,
            miUsuarioId: widget.conductorId,
            otroUsuarioId: clienteIdToUse,
            miTipo: 'conductor',
            otroNombre: widget.clienteNombre ?? 'Cliente',
            otroFoto: widget.clienteFoto,
            otroSubtitle: 'Tu pasajero',
          ),
        ),
      );
      debugPrint('✅ [Chat] ChatScreen abierta exitosamente');
    } catch (e) {
      debugPrint('❌ [Chat] Error al abrir ChatScreen: $e');
      _showStatus('Error al abrir el chat: $e', AppColors.error);
    }
  }

  void _showOptionsMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OptionsSheet(
        isDark: isDark,
        onCancel: () {
          Navigator.pop(ctx);
          _showCancelDialog(isDark);
        },
        onSupport: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HelpScreen(
                userType: HelpUserType.conductor,
                userId: widget.conductorId,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onCancelTrip() async {
    if (widget.solicitudId == null) return;

    if (_isProcessingAction) {
      return;
    }

    if (_pendingCancelSync) {
      if (!ConnectivityService().isOnline) {
        _showStatus(
          'Cancelación pendiente. Se sincronizará al reconectar.',
          AppColors.warning,
        );
        return;
      }

      _showStatus('Reintentando cancelación pendiente...', AppColors.warning);
      await _retryPendingCancelWithoutTap();
      return;
    }

    setState(() {
      _isProcessingAction = true;
      _processingActionType = 'cancel';
    });

    _showStatus('Cancelando viaje...', AppColors.primary);

    final payload = <String, dynamic>{
      'conductor_id': widget.conductorId,
      'solicitud_id': widget.solicitudId,
      'nuevo_estado': 'cancelada',
      'motivo_cancelacion': 'Cancelado por el conductor',
    };

    final cancelResult = await TripCommandExecutor.instance.enqueueAndTryNow(
      tripId: widget.solicitudId!,
      type: TripCommandType.cancelTrip,
      payload: payload,
    );

    if (cancelResult.success) {
      _completePendingCancelAndNavigate();
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessingAction = false;
        _processingActionType = null;
        _pendingCancelSync = cancelResult.pending;
      });
    } else {
      _isProcessingAction = false;
      _processingActionType = null;
      _pendingCancelSync = cancelResult.pending;
    }

    if (cancelResult.pending) {
      _startPendingCancelRetry();
      _showStatus(
        'Sin conexión estable. La cancelación se enviará al reconectar.',
        AppColors.warning,
      );
      return;
    }

    if (mounted) {
      _showStatus(
        cancelResult.message.isNotEmpty
            ? cancelResult.message
            : 'Error al cancelar viaje',
        AppColors.warning,
      );
    }
  }

  void _showCancelDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cancelar viaje?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.grey[900],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer y puede afectar tu calificación.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Volver',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo
              _onCancelTrip(); // Ejecutar cancelación real
            },
            child: Text(
              'Cancelar viaje',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[100],
        body: Stack(
          children: [
            // Mapa
            Positioned.fill(child: _buildMap(isDark)),

            // Controles superiores
            Positioned(
              top: statusBarHeight + 8,
              left: 12,
              right: 12,
              child: _buildTopControls(isDark),
            ),

            // Card de navegación
            Positioned(
              top: statusBarHeight + 70,
              left: 16,
              right: 16,
              child: _buildNavigationCard(isDark),
            ),

            // Mensajes de estado (Llegada, Inicio de viaje, etc)
            if (_statusMessage != null)
              Positioned(
                top: statusBarHeight + 180,
                left: 20,
                right: 20,
                child: _buildStatusMessage(),
              ),

            // Controles del mapa
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.42,
              right: 16,
              child: _buildMapControls(isDark),
            ),

            // Indicador de velocidad
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.42,
              left: 16,
              child: SpeedIndicator(
                currentSpeed: _controller.currentSpeed,
                isDark: isDark,
              ),
            ),

            // Panel inferior
            _buildBottomPanel(isDark),

            // Loading overlay
            if (_controller.loadingRoute)
              Positioned.fill(child: LoadingOverlay(isDark: isDark)),

            // Error banner
            if (_controller.error != null)
              Positioned(
                top: statusBarHeight + 140,
                left: 16,
                right: 16,
                child: ErrorBanner(
                  message: _controller.error!,
                  onRetry: () {
                    HapticFeedback.lightImpact();
                    _controller.loadRoute();
                  },
                  onDismiss: () => setState(() => _controller.error = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _triggerMapRenderRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.isDisposed) return;
      setState(() {});
    });
  }

  void _onMapCreated(MapboxMap map) {
    unawaited(_controller.onMapCreated(map));
    _triggerMapRenderRefresh();
  }

  void _onMapStyleLoaded() {
    unawaited(() async {
      await _controller.onStyleLoaded();
      if (!mounted || _controller.isDisposed) return;

      _triggerMapRenderRefresh();
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted || _controller.isDisposed) return;
      await _controller.moveCameraToDriver();
    }());
  }

  Widget _buildMap(bool isDark) {
    if (_controller.mapError) {
      return MapFallback(
        isDark: isDark,
        onRetry: () {
          HapticFeedback.lightImpact();
          GlobalMapHolder.invalidate(ownerKey: _mapOwnerKey);
          setState(() => _controller.mapError = false);
        },
      );
    }

    return GlobalMapHolder.resolve(
      ownerKey: _mapOwnerKey,
      builder: () => MapWidget(
        key: const ValueKey('persistent_conductor_trip_map'),
        cameraOptions: CameraOptions(
          center: _controller.driverLocation ?? _controller.pickup,
          zoom: 16,
          // Comenzar sin pitch para evitar congelamientos en algunos GPUs
          pitch: 0,
          bearing: _controller.currentBearing,
        ),
        styleUri: ActiveTripController.stableMapStyleUri,
        onMapCreated: _onMapCreated,
        textureView: true,
        androidHostingMode: AndroidPlatformViewHostingMode.TLHC_HC,
        onStyleLoadedListener: (_) => _onMapStyleLoaded(),
        onMapLoadErrorListener: _controller.onMapLoadError,
      ),
    );
  }

  Widget _buildTopControls(bool isDark) {
    return Row(
      children: [
        // Botón de regresar al home (el viaje sigue activo)
        FloatingButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: _navigateToHomeKeepingTrip,
          isDark: isDark,
          size: 44,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TripStatusPill(
            toPickup: _controller.toPickup,
            arrivedAtPickup: _controller.arrivedAtPickup,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        FloatingButton(
          icon: Icons.more_vert_rounded,
          onTap: () => _showOptionsMenu(isDark),
          isDark: isDark,
          size: 44,
        ),
      ],
    );
  }

  /// Navega al home pero mantiene el viaje activo (FAB flotante aparecerá)
  Future<void> _navigateToHomeKeepingTrip() async {
    HapticFeedback.lightImpact();
    // Marcar que salimos de la pantalla de viaje pero el viaje sigue activo
    ActiveTripNavigationService().setOnTripScreen(false);

    // Si podemos hacer pop, genial (caso normal)
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // Si no hay nada en el stack (ej. recuperación desde Splash),
      // forzar navegación al home
      final session = await UserService.getSavedSession();
      if (mounted) {
        // Usar pushNamedAndRemoveUntil para asegurar un stack limpio
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.conductorHome,
          (route) => false,
          arguments: {
            'conductor_user': session ?? {},
          }, // Pasar mapa vacío como fallback seguro
        );
      }
    }
  }

  Widget _buildNavigationCard(bool isDark) {
    final target = _controller.toPickup
        ? _controller.pickup
        : _controller.dropoff;

    double dist = _controller.driverLocation != null
        ? _controller.calculateDistance(_controller.driverLocation!, target)
        : 0;

    String distText = dist < 1000
        ? '${dist.toInt()} m'
        : '${(dist / 1000).toStringAsFixed(1)} km';

    return NavigationCard(
      distanceText: distText,
      etaMinutes: _controller.etaMinutes,
      toPickup: _controller.toPickup,
      isDark: isDark,
    );
  }

  Widget _buildMapControls(bool isDark) {
    return Column(
      children: [
        FloatingButton(
          icon: Icons.my_location_rounded,
          onTap: _controller.centerOnDriver,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        FloatingButton(
          icon: _controller.is3DMode ? Icons.view_in_ar : Icons.map_outlined,
          onTap: _controller.toggle3DMode,
          isDark: isDark,
          isActive: _controller.is3DMode,
        ),
      ],
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    final fallbackDistance = _controller.driverLocation != null
        ? _controller.calculateDistance(
                _controller.driverLocation!,
                _controller.pickup,
              ) /
              1000
        : 0.0;

    final displayDistance = _controller.distanceKm > 0
        ? _controller.distanceKm
        : fallbackDistance;

    final arrivalTime = _controller.etaMinutes > 0
        ? DateTime.now().add(Duration(minutes: _controller.etaMinutes))
        : null;

    final arrivalLabel = arrivalTime != null
        ? '${arrivalTime.hour.toString().padLeft(2, '0')}:'
              '${arrivalTime.minute.toString().padLeft(2, '0')}'
        : '--:--';

    // Obtener coordenadas actuales del conductor
    final currentLat = _controller.driverLocation?.coordinates.lat.toDouble();
    final currentLng = _controller.driverLocation?.coordinates.lng.toDouble();

    return TripBottomPanel(
      isDark: isDark,
      toPickup: _controller.toPickup,
      arrivedAtPickup: _controller.arrivedAtPickup,
      passengerName: widget.clienteNombre ?? '',
      passengerPhoto: widget.clienteFoto,
      passengerRating: widget.clienteCalificacion,
      pickupAddress: widget.direccionOrigen,
      destinationAddress: widget.direccionDestino,
      etaMinutes: _controller.etaMinutes,
      distanceKm: displayDistance,
      arrivalTime: arrivalLabel,
      isLoading: _isProcessingAction || _controller.loadingRoute,
      onArrivedPickup: _onArrivedPickup,
      onStartTrip: _onStartTrip,
      onFinishTrip: _onFinishTrip,
      onMessage: _openChat,
      // Coordenadas para navegación externa
      pickupLat: widget.origenLat,
      pickupLng: widget.origenLng,
      destinationLat: widget.destinoLat,
      destinationLng: widget.destinoLng,
      currentLat: currentLat,
      currentLng: currentLng,
      unreadCount: _unreadCount,
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _statusColor ?? AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_statusColor ?? AppColors.primary).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _statusMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGETS AUXILIARES
// =============================================================================

class _OptionsSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCancel;
  final VoidCallback onSupport;

  const _OptionsSheet({
    required this.isDark,
    required this.onCancel,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          _OptionItem(
            icon: Icons.cancel_outlined,
            label: 'Cancelar viaje',
            color: AppColors.error,
            isDark: isDark,
            onTap: onCancel,
          ),
          const SizedBox(height: 8),
          _OptionItem(
            icon: Icons.support_agent_rounded,
            label: 'Contactar soporte',
            isDark: isDark,
            onTap: onSupport,
          ),
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionItem({
    required this.icon,
    required this.label,
    this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? (isDark ? Colors.white : Colors.grey[800]);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

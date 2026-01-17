import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/conductor/services/conductor_service.dart';
import 'package:viax/src/global/widgets/chat/chat_widgets.dart';
import 'package:viax/src/global/widgets/trip_completion/trip_completion_widgets.dart';
import 'package:viax/src/global/services/rating_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/chat_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../global/services/local_notification_service.dart';
import '../widgets/active_trip/active_trip_widgets.dart';
import '../widgets/common/floating_button.dart';
import '../controllers/active_trip_controller.dart';

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
  });

  @override
  State<ConductorActiveTripScreen> createState() =>
      _ConductorActiveTripScreenState();
}

class _ConductorActiveTripScreenState extends State<ConductorActiveTripScreen>
    with WidgetsBindingObserver {
  late final ActiveTripController _controller;
  
  // Estado para mensajes flotantes
  String? _statusMessage;
  Color? _statusColor;
  Timer? _statusTimer;
  DateTime? _tripStartTime; // Para calcular duración real

  late final StreamSubscription<List<ChatMessage>> _messagesSubscription;
  late final StreamSubscription<int> _unreadSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.solicitudId != null && widget.clienteId != null) {
      ChatService.startPolling(
        solicitudId: widget.solicitudId!,
        usuarioId: widget.conductorId,
      );
      _setupChatListeners();
    }
    _initController();
  }

  void _initController() {
    _controller = ActiveTripController(
      origenLat: widget.origenLat,
      origenLng: widget.origenLng,
      destinoLat: widget.destinoLat,
      destinoLng: widget.destinoLng,
      onStateChanged: _onControllerStateChanged,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _messagesSubscription.cancel();
    _unreadSubscription.cancel();
    ChatService.stopPolling();
    super.dispose();
  }

  void _setupChatListeners() {
    // Escuchar mensajes nuevos
    _messagesSubscription = ChatService.messagesStream.listen((messages) {
      if (messages.isEmpty) return;

      final lastMsg = messages.last;

      // Si el chat está abierto, no hacer nada
      if (ChatService.isChatOpen) return;

      // Si el mensaje es del cliente y es reciente (menos de 10s)
      if (lastMsg.remitenteId != widget.conductorId &&
          DateTime.now().difference(lastMsg.fechaCreacion).inSeconds < 10) {
        
        // Reproducir sonido de mensaje
        SoundService.playMessageSound();
        
        LocalNotificationService.showMessageNotification(
          title: lastMsg.remitenteNombre ?? 'Cliente',
          body: lastMsg.mensaje,
          solicitudId: widget.solicitudId,
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
        setState(() => _unreadCount = count);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.positionStream?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller.positionStream?.resume();
    }
  }

  void _onControllerStateChanged() {
    if (mounted && !_controller.isDisposed) {
      setState(() {});
    }
  }

  // ===========================================================================
  // ACCIONES
  // ===========================================================================

  /// Notifica al backend que el conductor llegó al punto de recogida.
  Future<void> _onArrivedPickup() async {
    if (widget.solicitudId != null) {
      try {
        await ConductorService.notificarLlegadaRecogida(
          conductorId: widget.conductorId,
          solicitudId: widget.solicitudId!,
        );
      } catch (e) {
        debugPrint('Error notificando llegada: $e');
      }
    }

    await _controller.onArrivedPickup();
    if (!mounted || _controller.isDisposed) return;

    _showStatus('¡Llegaste al punto! Espera al pasajero', AppColors.accent);
  }

  /// Inicia el viaje cuando el cliente se sube al vehículo.
  Future<void> _onStartTrip() async {
    if (widget.solicitudId != null) {
      try {
        final success = await ConductorService.iniciarViaje(
          conductorId: widget.conductorId,
          solicitudId: widget.solicitudId!,
        );
        if (!success) {
          _showStatus('Error al iniciar el viaje', AppColors.error);
          return;
        }
      } catch (e) {
        debugPrint('Error iniciando viaje: $e');
        _showStatus('Error al iniciar el viaje', AppColors.error);
        return;
      }
    }

    await _controller.onStartTrip();
    if (!mounted || _controller.isDisposed) return;

    // Registrar tiempo de inicio
    _tripStartTime = DateTime.now();

    _showStatus('¡Viaje iniciado! Navegando al destino', AppColors.success);
  }

  /// Finaliza el viaje cuando se llega al destino.
  Future<void> _onFinishTrip() async {
    if (widget.solicitudId != null) {
      try {
        final success = await ConductorService.completarViaje(
          conductorId: widget.conductorId,
          solicitudId: widget.solicitudId!,
        );
        if (!success) {
          _showStatus('Error al finalizar el viaje', AppColors.error);
          return;
        }
      } catch (e) {
        debugPrint('Error finalizando viaje: $e');
        _showStatus('Error al finalizar el viaje', AppColors.error);
        return;
      }
    }

    if (!mounted) return;
    
    // Navegar a pantalla de completación
    _navigateToTripCompletion();
  }

  /// Navega a la pantalla de completación del viaje.
  void _navigateToTripCompletion() {
    // Calcular datos del viaje
    final distanciaKm = _controller.distanceKm > 0 
        ? _controller.distanceKm 
        : 5.0; // Fallback
    // Calcular duración real del viaje
    // Si no hay hora de inicio registrada, usar fallback de 15 min
    final duracionMin = _tripStartTime != null
        ? DateTime.now().difference(_tripStartTime!).inMinutes
        : (_controller.etaMinutes > 0 ? _controller.etaMinutes : 15);
    
    // TODO: Obtener precio real del backend
    final precio = distanciaKm * 2500; // Estimado
    
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
            duracionMinutos: duracionMin,
            precio: precio,
            metodoPago: 'Efectivo', // TODO: Obtener del backend
            otroUsuarioNombre: widget.clienteNombre ?? 'Pasajero',
            otroUsuarioFoto: widget.clienteFoto,
          ),
          miUsuarioId: widget.conductorId,
          otroUsuarioId: widget.clienteId ?? 0,
          onSubmitRating: (rating, comentario) async {
            if (widget.clienteId == null) return false;
            final result = await RatingService.enviarCalificacion(
              solicitudId: widget.solicitudId ?? 0,
              calificadorId: widget.conductorId,
              calificadoId: widget.clienteId!,
              calificacion: rating,
              tipoCalificador: 'conductor',
              comentario: comentario,
            );
            return result['success'] == true;
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
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
      debugPrint('⚠️ [Chat] clienteId es null, mostrando diálogo de información');
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
        onSupport: () => Navigator.pop(ctx),
        onReport: () => Navigator.pop(ctx),
      ),
    );
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
              Navigator.pop(ctx);
              Navigator.pop(context, false);
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
                  onDismiss: () => setState(() => _controller.error = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    if (_controller.mapError) {
      return MapFallback(
        isDark: isDark,
        onRetry: () {
          HapticFeedback.lightImpact();
          setState(() => _controller.mapError = false);
        },
      );
    }

    return MapWidget(
      key: const ValueKey('conductorTripMap'),
      cameraOptions: CameraOptions(
        center: _controller.driverLocation ?? _controller.pickup,
        zoom: 16,
        // Comenzar sin pitch para evitar congelamientos en algunos GPUs
        pitch: 0,
        bearing: _controller.currentBearing,
      ),
      styleUri: isDark
          ? 'mapbox://styles/mapbox/navigation-night-v1'
          : 'mapbox://styles/mapbox/navigation-day-v1',
      onMapCreated: _controller.onMapCreated,
      textureView: true,
      androidHostingMode: AndroidPlatformViewHostingMode.TLHC_HC,
      onStyleLoadedListener: (eventData) => _controller.onStyleLoaded(),
      onMapLoadErrorListener: _controller.onMapLoadError,
    );
  }

  Widget _buildTopControls(bool isDark) {
    return Row(
      children: [
        FloatingButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context, true),
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
      pickupAddress: widget.direccionOrigen,
      destinationAddress: widget.direccionDestino,
      etaMinutes: _controller.etaMinutes,
      distanceKm: displayDistance,
      arrivalTime: arrivalLabel,
      isLoading: _controller.loadingRoute,
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
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
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
  final VoidCallback onReport;

  const _OptionsSheet({
    required this.isDark,
    required this.onCancel,
    required this.onSupport,
    required this.onReport,
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
          const SizedBox(height: 8),
          _OptionItem(
            icon: Icons.report_problem_outlined,
            label: 'Reportar problema',
            isDark: isDark,
            onTap: onReport,
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

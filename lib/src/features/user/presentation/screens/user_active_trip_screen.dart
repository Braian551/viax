import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../global/services/rating_service.dart';
import '../../../../global/services/chat_service.dart';
import '../../../../global/services/local_notification_service.dart';
import '../../../../global/widgets/chat/chat_widgets.dart';
import '../../../../global/widgets/trip_completion/trip_completion_widgets.dart';
import '../../../../theme/app_colors.dart';
import '../../services/trip_request_service.dart';
import '../../services/client_tracking_service.dart';
import 'package:viax/src/global/services/trip_persistence_service.dart';
import '../widgets/user_active_trip/user_active_trip_widgets.dart';

/// Pantalla de viaje activo para el usuario/cliente.
///
/// Muestra el progreso del viaje desde que el conductor recoge
/// al cliente hasta llegar al destino. Estilo Uber/DiDi.
class UserActiveTripScreen extends StatefulWidget {
  final int solicitudId;
  final int clienteId;
  final double origenLat;
  final double origenLng;
  final String direccionOrigen;
  final double destinoLat;
  final double destinoLng;
  final String direccionDestino;
  final Map<String, dynamic>? conductorInfo;

  const UserActiveTripScreen({
    super.key,
    required this.solicitudId,
    required this.clienteId,
    required this.origenLat,
    required this.origenLng,
    required this.direccionOrigen,
    required this.destinoLat,
    required this.destinoLng,
    required this.direccionDestino,
    this.conductorInfo,
  });

  @override
  State<UserActiveTripScreen> createState() => _UserActiveTripScreenState();
}

class _UserActiveTripScreenState extends State<UserActiveTripScreen>
    with TickerProviderStateMixin {
  // Controladores
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Servicio de tracking del cliente
  final ClientTripTrackingService _trackingService = ClientTripTrackingService();

  // Estado del viaje
  String _tripState = 'en_curso';
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<int>? _unreadSubscription;
  int _unreadCount = 0;
  bool _disposed = false;
  
  LatLng? _conductorLocation;
  double _conductorHeading = 0;
  LatLng? _clientLocation;
  double _clientHeading = 0;
  Map<String, dynamic>? _conductor;

  // Ruta y progreso
  List<LatLng> _routePoints = [];
  List<LatLng> _animatedRoute = [];
  double _distanceKm = 0; // Distancia RESTANTE
  double? _distanceTraveled; // Distancia RECORRIDA (real)
  int _etaMinutes = 0;
  double _tripProgress = 0;
  
  // Datos de tracking en tiempo real (sincronizado con conductor)
  double _precioActual = 0;
  int _tiempoTranscurridoSeg = 0;
  bool _trackingActivo = false;
  
  // Tiempos reales
  DateTime? _tripStartTime;
  int _elapsedMinutes = 0;

  // Timers
  Timer? _statusTimer;
  Timer? _routeAnimationTimer;
  Timer? _locationTimer;

  // Control de UI
  bool _isLoading = true;
  bool _tripCompleted = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeTrip();
    _startClientTracking();
  }

  @override
  void dispose() {
    _disposed = true;
    _tripCompleted = true; // Prevent any further status checks
    _statusTimer?.cancel();
    _statusTimer = null;
    _routeAnimationTimer?.cancel();
    _routeAnimationTimer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    _messagesSubscription?.cancel();
    _unreadSubscription?.cancel();
    _pulseController.dispose();
    _stopClientTracking();
    super.dispose();
  }
  
  /// Inicia la observación del tracking del conductor
  void _startClientTracking() {
    _trackingService.onTrackingUpdate = (data) {
      if (!mounted || _disposed) return;
      
      setState(() {
        _distanceTraveled = data.distanciaKm;
        _tiempoTranscurridoSeg = data.tiempoSegundos;
        _precioActual = data.precioActual;
        _trackingActivo = data.viajeEnCurso;
        _elapsedMinutes = data.tiempoMinutos;
        
        // Actualizar ubicación del conductor desde tracking
        if (data.latitudConductor != null && data.longitudConductor != null) {
          _conductorLocation = LatLng(data.latitudConductor!, data.longitudConductor!);
        }
      });
    };
    
    _trackingService.onError = (error) {
      debugPrint('⚠️ [ClientTracking] Error: $error');
    };
    
    _trackingService.startWatching(solicitudId: widget.solicitudId);
  }
  
  /// Detiene la observación del tracking
  void _stopClientTracking() {
    _trackingService.onTrackingUpdate = null;
    _trackingService.onError = null;
    _trackingService.stopWatching();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeTrip() async {
    // Cargar info del conductor si no viene
    _conductor = widget.conductorInfo;
    
    // Iniciar rastreo de ubicación del cliente
    _startLocationTracking();
    
    // Calcular ruta inicial
    await _loadRoute();
    
    // Iniciar polling de estado
    _startStatusPolling();
    
    // Iniciar polling de chat
    ChatService.startPolling(
      solicitudId: widget.solicitudId,
      usuarioId: widget.clienteId,
    );

    _setupChatListeners();

    if (mounted) {
      setState(() => _isLoading = false);
    }

    // Guardar estado para recuperación
    try {
      await TripPersistenceService().saveActiveTrip(
        tripId: widget.solicitudId,
        role: 'cliente',
        startTime: _tripStartTime ?? DateTime.now(),
        initialDistance: 0.0,
      );
    } catch (e) {
      debugPrint('Error guardando persistencia: $e');
    }
  }

  void _startLocationTracking() async {
    try {
      // Verificar permisos
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Servicio de ubicación desactivado');
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.deniedForever ||
          permission == geo.LocationPermission.denied) {
        debugPrint('Permisos de ubicación denegados');
        return;
      }

      // Obtener posición actual
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _clientLocation = LatLng(position.latitude, position.longitude);
          _clientHeading = position.heading;
        });
      }

      // Iniciar stream de ubicación
      _locationTimer?.cancel();
      geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (mounted) {
          setState(() {
            _clientLocation = LatLng(position.latitude, position.longitude);
            _clientHeading = position.heading;
          });
        }
      });
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
    }
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkTripStatus();
    });
    _checkTripStatus();
  }

  void _setupChatListeners() {
    // Escuchar mensajes nuevos
    _messagesSubscription = ChatService.messagesStream.listen((messages) {
      if (_disposed || messages.isEmpty) return;

      final lastMsg = messages.last;
      
      // Si el chat está abierto, no hacer nada
      if (ChatService.isChatOpen) return;

      // Si el mensaje es del otro usuario y es reciente (menos de 10s)
      if (lastMsg.remitenteId != widget.clienteId &&
          DateTime.now().difference(lastMsg.fechaCreacion).inSeconds < 10) {
        
        // Reproducir sonido de mensaje
        SoundService.playMessageSound();
        
        LocalNotificationService.showMessageNotification(
          title: lastMsg.remitenteNombre ?? 'Conductor',
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
      if (mounted && !_disposed) {
        setState(() => _unreadCount = count);
      }
    });
  }

  Future<void> _checkTripStatus() async {
    if (!mounted || _tripCompleted) return;

    try {
      final result = await TripRequestService.getTripStatus(
        solicitudId: widget.solicitudId,
      );

      if (!mounted || _tripCompleted) return;

      if (result['success'] == true) {
        final trip = result['trip'];
        final estado = trip['estado'] as String?;
        // El conductor viene dentro de trip, no en la raíz
        final conductor = trip['conductor'] as Map<String, dynamic>?;

        // Recuperar hora de inicio real
        if (trip['hora_inicio'] != null) {
          try {
            _tripStartTime = DateTime.parse(trip['hora_inicio']);
            _elapsedMinutes = DateTime.now().difference(_tripStartTime!).inMinutes;
          } catch (e) {
            debugPrint('Error parsing start time: $e');
          }
        }

        // Actualizar datos de tracking desde la solicitud
        // SOLO si el tracking en tiempo real NO está activo (evita parpadeos)
        if (!_trackingActivo) {
          if (trip['distancia_recorrida'] != null) {
            _distanceTraveled = (trip['distancia_recorrida'] as num).toDouble();
          }
          
          // Obtener tiempo del tracking si está disponible
          if (trip['tiempo_transcurrido'] != null) {
            _tiempoTranscurridoSeg = (trip['tiempo_transcurrido'] as num).toInt();
          }
          
          // Precio: prioridad -> precio_final > precio_en_tracking > precio_estimado
          if (trip['precio_final'] != null && (trip['precio_final'] as num) > 0) {
            _precioActual = (trip['precio_final'] as num).toDouble();
          } else if (trip['precio_en_tracking'] != null && (trip['precio_en_tracking'] as num) > 0) {
            _precioActual = (trip['precio_en_tracking'] as num).toDouble();
          } else if (trip['precio_estimado'] != null && _precioActual == 0) {
            _precioActual = (trip['precio_estimado'] as num).toDouble();
          }
        }

        // VERIFICAR ESTADOS FINALES
        if (estado == 'completada' || estado == 'entregado') {
          // Cuando el viaje está completo, SIEMPRE leer datos finales de la BD
          if (trip['distancia_recorrida'] != null) {
            _distanceTraveled = (trip['distancia_recorrida'] as num).toDouble();
          }
          if (trip['tiempo_transcurrido'] != null) {
            _tiempoTranscurridoSeg = (trip['tiempo_transcurrido'] as num).toInt();
          }
          if (trip['precio_final'] != null && (trip['precio_final'] as num) > 0) {
            _precioActual = (trip['precio_final'] as num).toDouble();
          }
          
          debugPrint('📊 [Cliente] Viaje completado - Datos finales:');
          debugPrint('   - Distancia: $_distanceTraveled km');
          debugPrint('   - Tiempo: $_tiempoTranscurridoSeg s');
          debugPrint('   - Precio: $_precioActual');
          _onTripCompleted();
          return;
        } else if (estado == 'cancelada') {
          _onTripCancelled();
          return;
        }



        // Actualizar ubicación del conductor
        LatLng? newConductorLocation;
        if (conductor != null) {
          final lat = (conductor['latitud'] as num?)?.toDouble();
          final lng = (conductor['longitud'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            newConductorLocation = LatLng(lat, lng);
          }
        }

        // Calcular progreso y ETA
        if (newConductorLocation != null) {
          final totalDistance = const Distance().as(
            LengthUnit.Kilometer,
            LatLng(widget.origenLat, widget.origenLng),
            LatLng(widget.destinoLat, widget.destinoLng),
          );

          final remainingDistance = const Distance().as(
            LengthUnit.Kilometer,
            newConductorLocation,
            LatLng(widget.destinoLat, widget.destinoLng),
          );

          _tripProgress = 1 - (remainingDistance / totalDistance).clamp(0, 1);
          _distanceKm = remainingDistance;
          _etaMinutes = (remainingDistance / 0.5 * 60).ceil(); // ~30km/h promedio
        }



        // Solo actualizar UI si seguimos activos
        if (mounted && !_tripCompleted) {
          setState(() {
            _tripState = estado ?? 'en_curso';
            if (conductor != null) {
              _conductor = conductor;
            }
            if (newConductorLocation != null) {
              _conductorLocation = newConductorLocation;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking trip status: $e');
    }
  }

  Future<void> _loadRoute() async {
    try {
      final start = LatLng(widget.origenLat, widget.origenLng);
      final end = LatLng(widget.destinoLat, widget.destinoLng);

      final route = await MapboxService.getRoute(waypoints: [start, end]);
      if (route != null && mounted) {
        setState(() {
          _routePoints = route.geometry;
          _distanceKm = route.distanceKm;
          _etaMinutes = route.durationMinutes.ceil();
        });
        _animateRoute();
        _fitMapToRoute();
      }
    } catch (e) {
      debugPrint('Error loading route: $e');
    }
  }

  void _animateRoute() {
    if (_routePoints.isEmpty) return;

    int currentIndex = 0;
    _routeAnimationTimer?.cancel();
    _routeAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 20),
      (timer) {
        if (currentIndex >= _routePoints.length) {
          timer.cancel();
          return;
        }
        if (mounted) {
          setState(() {
            _animatedRoute = _routePoints.sublist(0, currentIndex + 1);
          });
        }
        currentIndex += 3;
      },
    );
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 300),
      ),
    );
  }

  void _onTripCompleted() {
    if (_tripCompleted) return;
    _tripCompleted = true;
    _statusTimer?.cancel();
    ChatService.stopPolling();

    HapticFeedback.heavyImpact();
    SoundService.playAcceptSound();

    // Mostrar diálogo de finalización
    _showCompletionDialog();
  }

  void _onTripCancelled() {
    _tripCompleted = true;
    _statusTimer?.cancel();
    ChatService.stopPolling();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Viaje cancelado')),
          ],
        ),
        content: const Text('El viaje ha sido cancelado.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    // Navegar a pantalla de completación en lugar de diálogo
    _navigateToTripCompletion();
  }

  /// Navega a la pantalla de completación del viaje.
  void _navigateToTripCompletion() {
    // Usar precio real del tracking si está disponible, sino tarifa mínima
    final precioFinal = _precioActual > 0 
        ? _precioActual 
        : 5000.0; // Tarifa mínima como fallback
    
    // Usar distancia real del tracking - si no hay tracking, es 0 (no se movió)
    final distanciaFinal = _distanceTraveled ?? 0.0;
    
    // Usar tiempo real del tracking en segundos
    final duracionSegundos = _tiempoTranscurridoSeg > 0 
        ? _tiempoTranscurridoSeg 
        : (_elapsedMinutes * 60);
    
    debugPrint('📊 [ClientTracking] Finalizando viaje:');
    debugPrint('   - Precio real tracking: $_precioActual');
    debugPrint('   - Distancia real: $distanciaFinal km');
    debugPrint('   - Tiempo real: ${duracionSegundos}s (${(duracionSegundos / 60).toStringAsFixed(1)} min)');
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TripCompletionScreen(
          userType: TripCompletionUserType.cliente,
          tripData: TripCompletionData(
            solicitudId: widget.solicitudId,
            origen: widget.direccionOrigen,
            destino: widget.direccionDestino,
            distanciaKm: distanciaFinal,
            duracionSegundos: duracionSegundos,
            precio: precioFinal,
            metodoPago: 'Efectivo', // TODO: Obtener del backend
            otroUsuarioNombre: _conductor?['nombre'] ?? 'Conductor',
            otroUsuarioFoto: _conductor?['foto'] as String?,
            otroUsuarioCalificacion: (_conductor?['calificacion'] as num?)?.toDouble(),
          ),
          miUsuarioId: widget.clienteId,
          otroUsuarioId: (_conductor?['id'] as int?) ?? 0,
          onSubmitRating: (rating, comentario) async {
            final conductorId = _conductor?['id'] as int?;
            if (conductorId == null) return false;
            final result = await RatingService.enviarCalificacion(
              solicitudId: widget.solicitudId,
              calificadorId: widget.clienteId,
              calificadoId: conductorId,
              calificacion: rating,
              tipoCalificador: 'cliente',
              comentario: comentario,
            );
            return result['success'] == true;
          },
          onComplete: () {
            // Volver a la pantalla principal
            // Limpiar persistencia de viaje activo
            TripPersistenceService().clearActiveTrip();

            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
    );
  }

  void _openChat() {
    final conductorId = _conductor?['id'] as int?;
    if (conductorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat no disponible')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          solicitudId: widget.solicitudId,
          miUsuarioId: widget.clienteId,
          otroUsuarioId: conductorId,
          miTipo: 'cliente',
          otroNombre: _conductor?['nombre'] ?? 'Conductor',
          otroFoto: _conductor?['foto'],
          otroSubtitle: 'Tu conductor',
        ),
      ),
    ).then((_) {
      // Al volver del chat, actualizar conteo
      ChatService.getUnreadCount(
        solicitudId: widget.solicitudId,
        usuarioId: widget.clienteId,
      ).then((count) {
        if (mounted) setState(() => _unreadCount = count);
      });
    });
  }

  double _estDistance() {
    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(widget.origenLat, widget.origenLng),
      LatLng(widget.destinoLat, widget.destinoLng),
    );
  }

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

            // Header con estado
            Positioned(
              top: statusBarHeight + 8,
              left: 12,
              right: 12,
              child: TripStatusHeader(
                tripState: _tripState,
                isDark: isDark,
                onBack: () => Navigator.pop(context),
              ),
            ),

            // Card de progreso
            Positioned(
              top: statusBarHeight + 70,
              left: 16,
              right: 16,
              child: TripProgressCard(
                distanceKm: _distanceKm,
                etaMinutes: _etaMinutes,
                elapsedMinutes: _elapsedMinutes > 0 ? _elapsedMinutes : null,
                progress: _tripProgress,
                isDark: isDark,
              ),
            ),

            // Botones de mapa
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.38,
              right: 16,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    onTap: _fitMapToRoute,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Panel inferior
            _buildBottomPanel(isDark),

            // Loading
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    final destination = LatLng(widget.destinoLat, widget.destinoLng);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: destination,
        initialZoom: 14,
        minZoom: 10,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
        ),

        // Ruta animada
        if (_animatedRoute.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _animatedRoute,
                strokeWidth: 5.0,
                color: AppColors.primary,
                borderStrokeWidth: 1.5,
                borderColor: Colors.white,
              ),
            ],
          ),

        // Marcadores
        MarkerLayer(
          markers: [
            // Cliente (ubicación actual)
            if (_clientLocation != null)
              Marker(
                point: _clientLocation!,
                width: 50,
                height: 50,
                child: _ClientMarker(heading: _clientHeading),
              ),

            // Conductor
            if (_conductorLocation != null)
              Marker(
                point: _conductorLocation!,
                width: 50,
                height: 50,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: _ConductorMarker(heading: _conductorHeading),
                    );
                  },
                ),
              ),

            // Destino
            Marker(
              point: destination,
              width: 50,
              height: 60,
              child: const _DestinationMarker(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.18,
      maxChildSize: 0.5,
      snap: true,
      snapSizes: const [0.18, 0.32, 0.5],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Info del viaje
                TripInfoPanel(
                  direccionDestino: widget.direccionDestino,
                  conductor: _conductor,
                  distanceKm: _distanceKm,
                  etaMinutes: _etaMinutes,
                  isDark: isDark,
                  precioActual: _precioActual,
                  distanciaRecorrida: _distanceTraveled,
                  tiempoTranscurrido: _tiempoTranscurridoSeg,
                ),

                const SizedBox(height: 16),

                // Botones de acción
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.message_rounded,
                          label: 'Mensaje',
                          onTap: _openChat,
                          isDark: isDark,
                          badgeCount: _unreadCount,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.share_location_rounded,
                          label: 'Compartir',
                          onTap: () {
                            // TODO: Compartir ubicación
                          },
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.support_agent_rounded,
                          label: 'Ayuda',
                          onTap: () {
                            // TODO: Centro de ayuda
                          },
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// WIDGETS AUXILIARES
// =============================================================================

class _ClientMarker extends StatelessWidget {
  final double heading;

  const _ClientMarker({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * (3.14159 / 180),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo exterior pulsante
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
          ),
          // Círculo principal
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConductorMarker extends StatelessWidget {
  final double heading;

  const _ConductorMarker({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * (3.14159 / 180),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.directions_car_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.flag_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _MapButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isDark ? Colors.white : Colors.grey[800],
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final int badgeCount;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isDark ? Colors.white : AppColors.primary,
                    size: 24,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 9 ? '9+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


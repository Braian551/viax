import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../global/services/rating_service.dart';
import '../../../../global/services/chat_service.dart';
import '../../../../global/services/local_notification_service.dart';
import '../../../../global/services/active_trip_navigation_service.dart';
import '../../../../global/widgets/map_retry_wrapper.dart';
import '../../../../global/widgets/chat/chat_widgets.dart';
import '../../../../global/widgets/trip_completion/trip_completion_widgets.dart';
import '../../../../theme/app_colors.dart';
import '../../services/trip_request_service.dart';
import '../../services/client_tracking_service.dart';
import 'package:viax/src/global/services/trip_persistence_service.dart';
import 'package:viax/src/features/location_sharing/services/location_sharing_service.dart';
import '../widgets/user_active_trip/user_active_trip_widgets.dart';
import '../widgets/user_active_trip/driver_detail_sheet.dart';

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
  static const double _headerDistanceRefreshThresholdKm = 0.03;
  static const double _headerProgressRefreshThreshold = 0.005;
  static const double _driverMoveRefreshThresholdKm = 0.02;

  // Controladores
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Servicio de tracking del cliente
  final ClientTripTrackingService _trackingService =
      ClientTripTrackingService();

  // Estado del viaje
  String _tripState = 'en_curso';
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<int>? _unreadSubscription;
  int _unreadCount = 0;
  final Set<int> _notifiedIncomingMessageIds = <int>{};
  bool _chatBootstrapCompleted = false;
  bool _disposed = false;

  LatLng? _conductorLocation;
  final double _conductorHeading = 0;
  LatLng? _clientLocation;
  double _clientHeading = 0;
  double _lastClientSpeedMps = 0.0;
  StreamSubscription<CompassEvent>? _compassStream;
  Map<String, dynamic>? _conductor;

  // Ruta y progreso
  List<LatLng> _routePoints = [];
  List<LatLng> _animatedRoute = [];
  double _distanceKm = 0; // Distancia RESTANTE
  double? _plannedRouteDistanceKm; // Distancia total estimada de la ruta
  double? _distanceTraveled; // Distancia RECORRIDA (real)
  int _etaMinutes = 0;
  double _tripProgress = 0;

  // Datos de tracking en tiempo real (sincronizado con conductor)
  double _precioActual = 0;
  int _tiempoTranscurridoSeg = 0;
  bool _trackingActivo = false;
  bool _finalMetricsLocked = false;
  Map<String, dynamic>? _desglosePrecioFinal;

  // Tiempos reales
  DateTime? _tripStartTime;
  int _elapsedMinutes = 0;

  // Timers
  Timer? _statusTimer;
  Timer? _routeAnimationTimer;
  Timer? _locationTimer;
  Timer? _localSecondsTimer;

  // Control de UI
  bool _isLoading = true;
  bool _tripCompleted = false;
  bool _isMapReady = false;
  bool _statusRequestInFlight = false;

  // Estado local para validar coherencia en métricas de tracking.
  double _lastAcceptedTrackingDistanceKm = 0.0;
  DateTime? _lastAcceptedTrackingSampleAt;

  // Compartir ubicación
  LocationShareSession? _shareSession;
  bool _isSharingLocation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refuerza el estado visible para evitar falsos positivos del FAB flotante
    ActiveTripNavigationService().setOnTripScreen(true);
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeTrip();
    _startClientTracking();
    _registerActiveTripNavigation();
    // Solicitar permiso de overlay al iniciar el viaje
    _requestSystemOverlayPermission();
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
    ActiveTripNavigationService().registerActiveTrip(
      ActiveTripData(
        solicitudId: widget.solicitudId,
        userId: widget.clienteId,
        userRole: 'cliente',
        origenLat: widget.origenLat,
        origenLng: widget.origenLng,
        direccionOrigen: widget.direccionOrigen,
        destinoLat: widget.destinoLat,
        destinoLng: widget.destinoLng,
        direccionDestino: widget.direccionDestino,
        conductorInfo: widget.conductorInfo,
        initialTripStatus: _tripState,
      ),
    );

    // Asegura estado consistente por si hubo cambios de ruta/lifecycle.
    ActiveTripNavigationService().setOnTripScreen(true);
  }

  @override
  void dispose() {
    _disposed = true;
    _tripCompleted = true; // Prevent any further status checks
    // Notificar que salimos de la pantalla de viaje
    ActiveTripNavigationService().setOnTripScreen(false);
    SoundService.stopDriverArrivedSound();
    _statusTimer?.cancel();
    _statusTimer = null;
    _routeAnimationTimer?.cancel();
    _routeAnimationTimer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    _localSecondsTimer?.cancel();
    _localSecondsTimer = null;
    _messagesSubscription?.cancel();
    _unreadSubscription?.cancel();
    _compassStream?.cancel();
    _pulseController.dispose();
    _stopClientTracking();
    // Stop live location sharing if active
    final token =
        _shareSession?.token ??
        LocationSharingService.instance.currentSession?.token;
    if (token != null && token.isNotEmpty) {
      unawaited(LocationSharingService.instance.stopSharingByToken(token));
    } else if (_isSharingLocation) {
      LocationSharingService.instance.stopSendingUpdates();
    }
    super.dispose();
  }

  Future<void> _stopLocationSharingSession() async {
    final token =
        _shareSession?.token ??
        LocationSharingService.instance.currentSession?.token;

    if (token != null && token.isNotEmpty) {
      await LocationSharingService.instance.stopSharingByToken(token);
    } else if (_isSharingLocation) {
      await LocationSharingService.instance.stopSharing();
    }

    if (!mounted) {
      _isSharingLocation = false;
      _shareSession = null;
      return;
    }

    setState(() {
      _isSharingLocation = false;
      _shareSession = null;
    });
  }

  /// Inicia la observación del tracking del conductor
  void _startClientTracking() {
    _trackingService.onTrackingUpdate = (data) {
      if (!mounted || _disposed) return;
      if (_finalMetricsLocked) return;

      setState(() {
        // Solo aceptar metricas de tracking si traen avance real.
        if (data.viajeEnCurso) {
          final distanciaActual = _distanceTraveled ?? 0.0;
          final now = DateTime.now();

          final tiempoBase = data.tiempoSegundos > 0
              ? data.tiempoSegundos
              : _tiempoTranscurridoSeg;

          if (data.distanciaKm > 0 && tiempoBase > 0) {
            var distanciaFiltrada = _clampRealtimeDistanceByTimeAndRoute(
              rawDistanceKm: data.distanciaKm,
              elapsedSeconds: tiempoBase,
            );

            final sampleTs = data.ultimaActualizacion ?? now;
            final previousTs = _lastAcceptedTrackingSampleAt;
            final previousDistance = _lastAcceptedTrackingDistanceKm;

            if (previousTs != null && distanciaFiltrada > previousDistance) {
              final dtSeconds = sampleTs
                  .difference(previousTs)
                  .inSeconds
                  .abs();
              final safeDt = dtSeconds > 0 ? dtSeconds : 1;
              final maxStepKm = ((safeDt / 3600.0) * 140.0) + 0.05;
              final maxAllowed = previousDistance + maxStepKm;
              if (distanciaFiltrada > maxAllowed) {
                distanciaFiltrada = maxAllowed;
              }
            }

            final nuevaDistancia = distanciaActual > distanciaFiltrada
                ? distanciaActual
                : distanciaFiltrada;

            _distanceTraveled = nuevaDistancia;
            _lastAcceptedTrackingDistanceKm = nuevaDistancia;
            _lastAcceptedTrackingSampleAt = sampleTs;
          }

          if (data.tiempoSegundos > 0) {
            _tiempoTranscurridoSeg =
                _tiempoTranscurridoSeg > data.tiempoSegundos
                ? _tiempoTranscurridoSeg
                : data.tiempoSegundos;
          }

          if (data.precioActual > 0 &&
              (data.tiempoSegundos > 0 || data.distanciaKm > 0) &&
              _precioActual == 0) {
            _precioActual = data.precioActual;
          }

          _trackingActivo =
              _tiempoTranscurridoSeg > 0 || (_distanceTraveled ?? 0) > 0;
          _elapsedMinutes = _tiempoTranscurridoSeg ~/ 60;
        }
        // Si no hay tracking activo, NO sobreescribir los valores
        // del status polling - solo marcar como inactivo
        else {
          _trackingActivo = false;
        }

        // Actualizar ubicación del conductor desde tracking
        if (data.latitudConductor != null && data.longitudConductor != null) {
          _conductorLocation = LatLng(
            data.latitudConductor!,
            data.longitudConductor!,
          );
        }
      });
    };

    _trackingService.onError = (error) {
      debugPrint('⚠️ [ClientTracking] Error: $error');
    };

    _trackingService.startWatching(solicitudId: widget.solicitudId);

    // Timer local para contar segundos en tiempo real
    // Esto asegura que el tiempo se actualice cada segundo
    // incluso cuando el backend no envía datos de tracking
    _localSecondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _disposed || _tripCompleted) return;
      if (_tripStartTime != null) {
        final localSeconds = DateTime.now()
            .difference(_tripStartTime!)
            .inSeconds;
        final shouldUpdate =
            (!_trackingActivo) || (localSeconds > _tiempoTranscurridoSeg);
        if (!shouldUpdate) return;

        setState(() {
          if (localSeconds > _tiempoTranscurridoSeg) {
            _tiempoTranscurridoSeg = localSeconds;
          }
        });
      }
    });
  }

  double _clampRealtimeDistanceByTimeAndRoute({
    required double rawDistanceKm,
    required int elapsedSeconds,
  }) {
    var safe = rawDistanceKm.isFinite ? rawDistanceKm : 0.0;
    if (safe < 0) safe = 0;
    if (elapsedSeconds <= 0) {
      return 0.0;
    }

    // Regla física: velocidad promedio no puede exceder un umbral alto pero plausible.
    final maxByTime = ((elapsedSeconds / 3600.0) * 140.0) + 0.15;
    if (safe > maxByTime) {
      safe = maxByTime;
    }

    // Regla de negocio: durante viaje en curso no debería exceder ampliamente la ruta prevista.
    if (_plannedRouteDistanceKm != null && _plannedRouteDistanceKm! > 0) {
      final maxByRoute = (_plannedRouteDistanceKm! * 1.6) + 1.0;
      if (safe > maxByRoute) {
        safe = maxByRoute;
      }
    }

    return safe;
  }

  /// Detiene la observación del tracking
  void _stopClientTracking() {
    _trackingService.onTrackingUpdate = null;
    _trackingService.onError = null;
    _trackingService.stopWatching();
    _localSecondsTimer?.cancel();
    _localSecondsTimer = null;
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
          _updateHeadingFromGps(position.heading, position.speed);
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
            _updateHeadingFromGps(position.heading, position.speed);
          });
        }
      });

      _startCompassTracking();
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
    }
  }

  void _startCompassTracking() {
    _compassStream?.cancel();
    _compassStream = FlutterCompass.events?.listen((event) {
      if (!mounted || _disposed) return;
      final heading = event.heading;
      if (heading == null || !heading.isFinite) return;

      if (_lastClientSpeedMps < 1.5) {
        setState(() {
          _clientHeading = _smoothHeading(
            _clientHeading,
            _normalizeHeading(heading),
          );
        });
      }
    });
  }

  void _updateHeadingFromGps(double heading, double speed) {
    _lastClientSpeedMps = speed;
    if (heading.isFinite && heading >= 0) {
      _clientHeading = _smoothHeading(
        _clientHeading,
        _normalizeHeading(heading),
      );
    }
  }

  double _normalizeHeading(double heading) {
    final normalized = heading % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double _smoothHeading(double current, double target, {double factor = 0.25}) {
    final delta = (((target - current + 540) % 360) - 180);
    return _normalizeHeading(current + delta * factor);
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkTripStatus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkTripStatus();
    });
  }

  void _setupChatListeners() {
    // Escuchar mensajes nuevos
    _messagesSubscription = ChatService.messagesStream.listen((messages) {
      if (_disposed || messages.isEmpty) return;

      if (!_chatBootstrapCompleted) {
        _chatBootstrapCompleted = true;
        for (final message in messages) {
          if (message.remitenteId != widget.clienteId) {
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
                message.remitenteId != widget.clienteId &&
                !_notifiedIncomingMessageIds.contains(message.id),
          )
          .toList();

      if (incomingMessages.isEmpty) return;

      if (mounted && !_disposed) {
        setState(() {
          _unreadCount += incomingMessages.length;
        });
      }

      for (final message in incomingMessages) {
        _notifiedIncomingMessageIds.add(message.id);

        // Reproducir sonido de mensaje
        SoundService.playMessageSound();

        LocalNotificationService.showMessageNotification(
          title: message.remitenteNombre ?? 'Conductor',
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
      if (mounted && !_disposed) {
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

  Future<void> _checkTripStatus() async {
    if (!mounted || _tripCompleted) return;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrentRoute) return;
    if (_statusRequestInFlight) return;

    _statusRequestInFlight = true;

    try {
      final result = await TripRequestService.getTripStatus(
        solicitudId: widget.solicitudId,
      );

      if (!mounted || _tripCompleted) return;

      if (result['success'] == true) {
        final trip = result['trip'];
        final estado = trip['estado'] as String?;
        final estadoNorm = (estado ?? '').toLowerCase();
        final hasTripStarted =
            estadoNorm == 'en_curso' ||
            estadoNorm == 'completada' ||
            estadoNorm == 'completado' ||
            estadoNorm == 'entregado' ||
            estadoNorm == 'finalizado';
        final metricsLocked = trip['metrics_locked'] == true;
        final desgloseRaw = trip['desglose_precio'];
        if (desgloseRaw is Map<String, dynamic>) {
          _desglosePrecioFinal = desgloseRaw;
        } else if (desgloseRaw is String && desgloseRaw.trim().isNotEmpty) {
          try {
            final parsed = jsonDecode(desgloseRaw);
            if (parsed is Map<String, dynamic>) {
              _desglosePrecioFinal = parsed;
            }
          } catch (_) {
            // Ignorar payload malformado y conservar último desglose válido.
          }
        }

        // El conductor viene dentro de trip, no en la raíz
        final conductor = trip['conductor'] as Map<String, dynamic>?;

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

        // Recuperar hora de inicio real
        if (trip['hora_inicio'] != null) {
          try {
            _tripStartTime = DateTime.parse(trip['hora_inicio']);
            _elapsedMinutes = DateTime.now()
                .difference(_tripStartTime!)
                .inMinutes;
          } catch (e) {
            debugPrint('Error parsing start time: $e');
          }
        }

        // Obtener tiempo del tracking si está disponible
        // Prioridad: duracion_segundos > tiempo_transcurrido_seg > tiempo_transcurrido*60 > local
        if (trip['duracion_segundos'] != null &&
            (trip['duracion_segundos'] as num) > 0) {
          _tiempoTranscurridoSeg = (trip['duracion_segundos'] as num).toInt();
        } else if (trip['tiempo_transcurrido_seg'] != null &&
            (trip['tiempo_transcurrido_seg'] as num) > 0) {
          _tiempoTranscurridoSeg = (trip['tiempo_transcurrido_seg'] as num)
              .toInt();
        } else if (trip['tiempo_transcurrido'] != null &&
            (trip['tiempo_transcurrido'] as num) > 0) {
          _tiempoTranscurridoSeg =
              (trip['tiempo_transcurrido'] as num).toInt() * 60;
        } else if (_tripStartTime != null && _tiempoTranscurridoSeg == 0) {
          // Fallback local: contar desde hora de inicio
          _tiempoTranscurridoSeg = DateTime.now()
              .difference(_tripStartTime!)
              .inSeconds;
        }

        // Actualizar distancia real desde status solo si hay tiempo coherente o métricas cerradas.
        if (trip['distancia_recorrida'] != null &&
            (trip['distancia_recorrida'] as num) > 0) {
          final rawDistance = (trip['distancia_recorrida'] as num).toDouble();
          final canUse = _tiempoTranscurridoSeg > 0 || metricsLocked;
          if (canUse) {
            final distanceFromStatus = _clampRealtimeDistanceByTimeAndRoute(
              rawDistanceKm: rawDistance,
              elapsedSeconds: _tiempoTranscurridoSeg > 0
                  ? _tiempoTranscurridoSeg
                  : 1,
            );
            final currentDistance = _distanceTraveled ?? 0.0;
            final nextDistance = currentDistance > distanceFromStatus
                ? currentDistance
                : distanceFromStatus;
            _distanceTraveled = nextDistance;
            _lastAcceptedTrackingDistanceKm = nextDistance;
            _lastAcceptedTrackingSampleAt = DateTime.now();
          }
        }

        // Precio: prioridad -> precio_en_tracking > precio_estimado
        // precio_final se usa solo al completar, durante el viaje usar precio_en_tracking
        if (trip['precio_en_tracking'] != null &&
            (trip['precio_en_tracking'] as num) > 0) {
          _precioActual = (trip['precio_en_tracking'] as num).toDouble();
        } else if (trip['precio_estimado'] != null) {
          _precioActual = (trip['precio_estimado'] as num).toDouble();
        }

        // Iniciar hora de inicio local solo cuando el viaje realmente arrancó.
        if (_tripStartTime == null && hasTripStarted) {
          if (trip['hora_inicio'] != null) {
            try {
              _tripStartTime = DateTime.parse(trip['hora_inicio']);
            } catch (_) {}
          }

          if (_tripStartTime == null && trip['fecha_aceptado'] != null) {
            try {
              _tripStartTime = DateTime.parse(trip['fecha_aceptado']);
            } catch (_) {}
          }

          _tripStartTime ??= DateTime.now();
        }

        // VERIFICAR ESTADOS FINALES
        if (estado == 'completada' ||
            estado == 'entregado' ||
            estado == 'completado' ||
            estado == 'finalizado') {
          _finalMetricsLocked = metricsLocked || trip['finalized_at'] != null;
          if (_finalMetricsLocked) {
            _stopClientTracking();
            debugPrint(
              '🛑 [TrackingStopped] trip_id=${widget.solicitudId} por metrics_locked',
            );
          }

          final canonicalDistance = toDouble(trip['distance_final']);
          final canonicalDuration = toInt(trip['duration_final']);
          final canonicalPrice = toDouble(trip['price_final_canonical']);

          // Cuando el viaje está completo, SIEMPRE leer datos finales de la BD
          debugPrint('📊 [Cliente] Datos crudos del backend:');
          debugPrint(
            '   - distancia_recorrida: ${trip['distancia_recorrida']}',
          );
          debugPrint(
            '   - tiempo_transcurrido: ${trip['tiempo_transcurrido']}',
          );
          debugPrint('   - duracion_minutos: ${trip['duracion_minutos']}');
          debugPrint('   - precio_final: ${trip['precio_final']}');

          // Distancia: usar real si existe
          if (canonicalDistance != null) {
            _distanceTraveled = canonicalDistance;
          } else if (trip['distancia_recorrida'] != null &&
              (trip['distancia_recorrida'] as num) > 0) {
            _distanceTraveled = (trip['distancia_recorrida'] as num).toDouble();
          }

          // Tiempo: prioridad -> duracion_segundos > tiempo_transcurrido_seg > tiempo_minutos*60 > local
          // El backend ahora devuelve tiempo en segundos exactos
          int tiempoFinalSegundos = 0;

          // Prioridad 1: usar duracion_segundos (valor exacto del backend)
          if (canonicalDuration != null) {
            tiempoFinalSegundos = canonicalDuration;
          }
          // Prioridad 1: usar duracion_segundos (valor exacto del backend)
          else if (trip['duracion_segundos'] != null &&
              (trip['duracion_segundos'] as num) > 0) {
            tiempoFinalSegundos = (trip['duracion_segundos'] as num).toInt();
          }
          // Prioridad 2: usar tiempo_transcurrido_seg (nuevo campo del backend)
          else if (trip['tiempo_transcurrido_seg'] != null &&
              (trip['tiempo_transcurrido_seg'] as num) > 0) {
            tiempoFinalSegundos = (trip['tiempo_transcurrido_seg'] as num)
                .toInt();
          }
          // Prioridad 3: convertir minutos a segundos (fallback)
          else if (trip['tiempo_transcurrido'] != null &&
              (trip['tiempo_transcurrido'] as num) > 0) {
            tiempoFinalSegundos =
                (trip['tiempo_transcurrido'] as num).toInt() * 60;
          } else if (trip['duracion_minutos'] != null &&
              (trip['duracion_minutos'] as num) > 0) {
            tiempoFinalSegundos =
                (trip['duracion_minutos'] as num).toInt() * 60;
          } else if (_tripStartTime != null) {
            tiempoFinalSegundos = DateTime.now()
                .difference(_tripStartTime!)
                .inSeconds;
          }

          // Usar el tiempo en segundos directamente
          if (tiempoFinalSegundos > 0) {
            _tiempoTranscurridoSeg = tiempoFinalSegundos;
          } else if (_tripStartTime != null) {
            // Fallback: calcular desde hora de inicio
            _tiempoTranscurridoSeg = DateTime.now()
                .difference(_tripStartTime!)
                .inSeconds;
          }

          // Precio: usar precio_final
          if (canonicalPrice != null) {
            _precioActual = canonicalPrice;
          } else if (trip['precio_final'] != null &&
              (trip['precio_final'] as num) > 0) {
            _precioActual = (trip['precio_final'] as num).toDouble();
          }

          debugPrint('📊 [Cliente] Viaje completado - Datos finales:');
          debugPrint('   - Distancia: $_distanceTraveled km');
          debugPrint(
            '   - Tiempo: $_tiempoTranscurridoSeg s (${_tiempoTranscurridoSeg / 60} min)',
          );
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
        double? nextTripProgress;
        double? nextDistanceKm;
        int? nextEtaMinutes;
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

          nextTripProgress = 1 - (remainingDistance / totalDistance).clamp(0, 1);
          nextDistanceKm = remainingDistance;
          nextEtaMinutes = (remainingDistance / 0.5 * 60)
              .ceil(); // ~30km/h promedio
        }

        // Solo actualizar UI si seguimos activos
        if (mounted && !_tripCompleted) {
          final previousState = _tripState;
          if (estado != null && estado.isNotEmpty) {
            ActiveTripNavigationService().updateActiveTripStatus(estado);
          }

          final stateChanged = (estado ?? 'en_curso') != _tripState;
          final progressChanged =
              nextTripProgress != null &&
              (nextTripProgress - _tripProgress).abs() >=
                  _headerProgressRefreshThreshold;
          final distanceChanged =
              nextDistanceKm != null &&
              (nextDistanceKm - _distanceKm).abs() >=
                  _headerDistanceRefreshThresholdKm;
          final etaChanged =
              nextEtaMinutes != null && nextEtaMinutes != _etaMinutes;
          final conductorMovedEnough =
              newConductorLocation != null &&
              (_conductorLocation == null ||
                  const Distance().as(
                        LengthUnit.Kilometer,
                        _conductorLocation!,
                        newConductorLocation,
                      ) >=
                      _driverMoveRefreshThresholdKm);
            final currentVehicle = _conductor?['vehiculo'] as Map<String, dynamic>?;
            final nextVehicle = conductor?['vehiculo'] as Map<String, dynamic>?;
            final conductorInfoChanged =
              conductor != null &&
              (
                _conductor == null ||
                _conductor?['id'] != conductor['id'] ||
                _conductor?['nombre'] != conductor['nombre'] ||
                _conductor?['foto'] != conductor['foto'] ||
                currentVehicle?['placa'] != nextVehicle?['placa']);

          final shouldRefreshUi =
              stateChanged ||
              progressChanged ||
              distanceChanged ||
              etaChanged ||
              conductorMovedEnough ||
              conductorInfoChanged;

          if (!shouldRefreshUi) {
            return;
          }

          setState(() {
            _tripState = estado ?? 'en_curso';
            if (nextTripProgress != null) {
              _tripProgress = nextTripProgress;
            }
            if (nextDistanceKm != null) {
              _distanceKm = nextDistanceKm;
            }
            if (nextEtaMinutes != null) {
              _etaMinutes = nextEtaMinutes;
            }
            if (conductor != null) {
              _conductor = conductor;
            }
            if (conductorMovedEnough && newConductorLocation != null) {
              _conductorLocation = newConductorLocation;
            }
          });

          // LÃ³gica de sonido de llegada
          if (_tripState == 'conductor_llego' &&
              previousState != 'conductor_llego') {
            SoundService.playDriverArrivedSound();
          } else if (_tripState == 'en_curso' &&
              previousState == 'conductor_llego') {
            SoundService.stopDriverArrivedSound();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking trip status: $e');
    } finally {
      _statusRequestInFlight = false;
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
          _plannedRouteDistanceKm = route.distanceKm;
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
    _routeAnimationTimer = Timer.periodic(const Duration(milliseconds: 20), (
      timer,
    ) {
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
    });
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty || !_isMapReady) return;

    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 300),
      ),
    );
  }

  Future<void> _onTripCompleted() async {
    if (_tripCompleted) return;
    _tripCompleted = true;
    _statusTimer?.cancel();
    ChatService.stopPolling();
    await _stopLocationSharingSession();

    HapticFeedback.heavyImpact();
    SoundService.playAcceptSound();

    // Si las métricas canónicas ya están bloqueadas por el backend,
    // NO volver a pedir tracking porque podría llegar un snapshot tardío.
    if (!_finalMetricsLocked) {
      try {
        final trackingData = await _trackingService.getTrackingOnce(
          widget.solicitudId,
        );
        if (trackingData != null &&
            !trackingData.esTerminal &&
            trackingData.tiempoSegundos > 0) {
          _tiempoTranscurridoSeg = trackingData.tiempoSegundos;
          _distanceTraveled = trackingData.distanciaKm;
          _precioActual = trackingData.precioActual;
          debugPrint('✅ [Cliente] Datos finales del tracking obtenidos:');
          debugPrint('   - Tiempo: $_tiempoTranscurridoSeg s');
          debugPrint('   - Distancia: $_distanceTraveled km');
          debugPrint('   - Precio: $_precioActual');
        }
      } catch (e) {
        debugPrint('⚠️ [Cliente] Error obteniendo tracking final: $e');
      }
    }

    // Navegar directamente a la pantalla de completación
    _navigateToTripCompletion();
  }

  void _onTripCancelled() {
    _tripCompleted = true;
    _statusTimer?.cancel();
    ChatService.stopPolling();
    unawaited(_stopLocationSharingSession());

    // Limpiar viaje activo
    TripPersistenceService().clearActiveTrip();
    ActiveTripNavigationService().clearActiveTrip();

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

  /// Muestra las opciones del viaje (cancelar, soporte, etc.)
  void _showOptionsMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            _buildOptionItem(
              icon: Icons.cancel_outlined,
              label: 'Cancelar viaje',
              color: AppColors.error,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                _showCancelConfirmation();
              },
            ),
            const SizedBox(height: 8),
            _buildOptionItem(
              icon: Icons.share_location_rounded,
              label: _isSharingLocation
                  ? 'Compartir (activo)'
                  : 'Compartir ubicación',
              color: _isSharingLocation ? AppColors.success : null,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                _shareLocation();
              },
            ),
            const SizedBox(height: 8),
            _buildOptionItem(
              icon: Icons.support_agent_rounded,
              label: 'Contactar soporte',
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Implementar soporte
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    Color? color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
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

  /// Muestra confirmación antes de cancelar el viaje
  void _showCancelConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Esta acción no se puede deshacer. Se notificará al conductor.',
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
              _cancelTripByClient();
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

  /// Cancela el viaje por iniciativa del cliente
  Future<void> _cancelTripByClient() async {
    // Obtener el ID del conductor del viaje activo
    final conductorId = _conductor?['id'] as int?;
    if (conductorId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se puede cancelar: información del conductor no disponible',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final result = await TripRequestService.cancelTripRequestWithReason(
      solicitudId: widget.solicitudId,
      conductorId: conductorId,
      motivo: 'Cancelado por el cliente',
      canceladoPor: 'cliente',
    );

    if (result['success'] == true) {
      setState(() => _isLoading = false);
      _onTripCancelled();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al cancelar'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Navega al home del usuario
  void _navigateToHome() {
    // Marcar que salimos de la pantalla de viaje pero el viaje sigue activo
    ActiveTripNavigationService().setOnTripScreen(false);

    // Si hay historial, volvemos al inicio (HomeUser debería estar abajo)
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      // Si no podemos hacer pop (estamos en la raiz por recuperación), ir explícitamente al home
      Navigator.pushReplacementNamed(context, RouteNames.home);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // COMPARTIR UBICACIÓN
  // ─────────────────────────────────────────────────────────────────────

  /// Creates or reuses an active share session and opens the native share sheet.
  Future<void> _shareLocation() async {
    // User ID required — obtain from conductor data or widget
    // The clienteId IS the current user (the passenger)
    final userId = widget.clienteId;

    // If already sharing, just re-share the link
    if (_isSharingLocation && _shareSession != null) {
      _openShareSheet(_shareSession!);
      return;
    }

    // Show loading indicator
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final session = await LocationSharingService.instance.createShare(
        userId: userId,
        solicitudId: widget.solicitudId,
        expiresMinutes: 120,
      );

      if (!mounted) return;
      setState(() {
        _shareSession = session;
        _isSharingLocation = true;
        _isLoading = false;
      });

      // Start broadcasting location in the background
      LocationSharingService.instance.startSendingUpdates();

      _openShareSheet(session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo compartir la ubicación: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openShareSheet(LocationShareSession session) {
    final nombre = _conductor?['nombre'] ?? 'mi conductor';
    final message =
        '📍 Estoy en un viaje con Viax junto a $nombre. '
        'Sigue mi ubicación en tiempo real:\n${session.shareUrl}';
    Share.share(message, subject: 'Mi ubicación en Viax');
  }

  /// Navega a la pantalla de completación del viaje.
  void _navigateToTripCompletion() {
    // Limpiar el viaje activo al completar
    TripPersistenceService().clearActiveTrip();
    ActiveTripNavigationService().clearActiveTrip();

    // Usar precio real del tracking si está disponible, sino tarifa mínima
    final precioFinal = _precioActual > 0
        ? _precioActual
        : 5000.0; // Tarifa mínima como fallback

    // Usar distancia real del tracking - si no hay tracking, es 0 (no se movió)
    final distanciaFinal = _distanceTraveled ?? 0.0;

    // Usar tiempo real del tracking en segundos
    final duracionSegundos = _tiempoTranscurridoSeg > 0
        ? _tiempoTranscurridoSeg
      : (_tripStartTime != null
          ? DateTime.now().difference(_tripStartTime!).inSeconds
          : (_elapsedMinutes * 60));

    final resumenCalculo = _precioActual > 0
        ? 'Total calculado con seguimiento del viaje en tiempo real (distancia y tiempo acumulados).'
        : 'Total mostrado con tarifa minima por ausencia temporal de datos de tracking en vivo.';

    debugPrint('📊 [ClientTracking] Finalizando viaje:');
    debugPrint('   - Precio real tracking: $_precioActual');
    debugPrint('   - Distancia real: $distanciaFinal km');
    debugPrint(
      '   - Tiempo real: ${duracionSegundos}s (${(duracionSegundos / 60).toStringAsFixed(1)} min)',
    );

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
            resumenCalculo: resumenCalculo,
            desglosePrecio: _desglosePrecioFinal,
            otroUsuarioNombre: _conductor?['nombre'] ?? 'Conductor',
            otroUsuarioFoto: _conductor?['foto'] as String?,
            otroUsuarioCalificacion: (_conductor?['calificacion'] as num?)
                ?.toDouble(),
          ),
          miUsuarioId: widget.clienteId,
          otroUsuarioId: (_conductor?['id'] as int?) ?? 0,
          onSubmitRating: (rating, comentario) async {
            final conductorId = _conductor?['id'] as int?;
            if (conductorId == null) {
              return {'success': false, 'message': 'Conductor no disponible'};
            }
            final result = await RatingService.enviarCalificacion(
              solicitudId: widget.solicitudId,
              calificadorId: widget.clienteId,
              calificadoId: conductorId,
              calificacion: rating,
              tipoCalificador: 'cliente',
              comentario: comentario,
            );
            return result;
          },
          onComplete: () {
            // Volver a la pantalla principal
            // Limpiar persistencia de viaje activo
            TripPersistenceService().clearActiveTrip();

            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
    );
  }

  void _openChat() {
    final conductorId = _conductor?['id'] as int?;
    if (conductorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat no disponible')));
      return;
    }

    setState(() => _unreadCount = 0);

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
                onBack: _navigateToHome,
                onOptions: _showOptionsMenu,
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

    return MapRetryWrapper(
      isDark: isDark,
      builder: ({required mapKey, required onMapReady, required onTileError}) =>
          FlutterMap(
            key: mapKey,
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destination,
              initialZoom: 14,
              minZoom: 10,
              maxZoom: 18,
              onMapReady: () {
                _isMapReady = true;
                onMapReady();
                if (_routePoints.isNotEmpty) {
                  _fitMapToRoute();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
                userAgentPackageName: 'com.viax.app',
                errorTileCallback: (tile, error, stackTrace) =>
                    onTileError(error, stackTrace),
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
          ),
    );
  }

  void _showDriverDetails() {
    debugPrint('🚀 _showDriverDetails called. Conductor: $_conductor');
    if (_conductor == null) {
      debugPrint('❌ Conductor is null, cannot show details');
      return;
    }
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => DriverDetailSheet(
          conductor: _conductor!,
          isDark: isDark,
          scrollController: controller,
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.18,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.18, 0.32, 0.55],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          AppColors.darkSurface.withValues(alpha: 0.93),
                          AppColors.darkBackground.withValues(alpha: 0.88),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.9),
                          AppColors.blue50.withValues(alpha: 0.8),
                        ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.66),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
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
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [Colors.white30, Colors.white12]
                              : [Colors.grey[400]!, Colors.grey[300]!],
                        ),
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
                      onDriverTap: _showDriverDetails,
                    ),

                    const SizedBox(height: 20),

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
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.person_rounded,
                              label: 'Perfil',
                              onTap: _showDriverDetails,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              icon: _isSharingLocation
                                  ? Icons.share_location_rounded
                                  : Icons.share_location_rounded,
                              label: _isSharingLocation
                                  ? 'Compartiendo'
                                  : 'Compartir',
                              onTap: _shareLocation,
                              isDark: isDark,
                              highlight: _isSharingLocation,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
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
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : AppColors.primary,
              size: 22,
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
  final bool highlight;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.badgeCount = 0,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(14),
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: highlight
                      ? [
                          AppColors.success.withValues(alpha: 0.2),
                          AppColors.success.withValues(alpha: 0.1),
                        ]
                      : isDark
                      ? [
                          Colors.white.withValues(alpha: 0.09),
                          Colors.white.withValues(alpha: 0.04),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.84),
                          AppColors.blue50.withValues(alpha: 0.52),
                        ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: highlight
                      ? AppColors.success.withValues(alpha: 0.35)
                      : isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.68),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: highlight
                            ? AppColors.success
                            : isDark
                            ? Colors.white70
                            : AppColors.primary,
                        size: 22,
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
                                color: isDark
                                    ? const Color(0xFF1C1C1E)
                                    : Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
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
                      color: highlight
                          ? AppColors.success
                          : isDark
                          ? Colors.white70
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

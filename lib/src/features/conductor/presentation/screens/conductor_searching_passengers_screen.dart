import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../theme/app_colors.dart';
import '../../services/trip_request_search_service.dart';
import '../../services/conductor_service.dart';
import '../widgets/route_3d_overlay.dart';
import 'conductor_active_trip_screen.dart';

/// Pantalla para mostrar y gestionar UNA solicitud de viaje a la vez
/// 
/// Lógica tipo Uber/InDrive/Didi:
/// - Muestra UNA solicitud a la vez
/// - Al aceptar: navega a pantalla de viaje activo
/// - Al rechazar: regresa al home para que busque la siguiente
/// - Otros conductores también pueden ver las mismas solicitudes
class ConductorSearchingPassengersScreen extends StatefulWidget {
  final int conductorId;
  final String conductorNombre;
  final String tipoVehiculo;
  final Map<String, dynamic> solicitud; // UNA solicitud a mostrar

  const ConductorSearchingPassengersScreen({
    super.key,
    required this.conductorId,
    required this.conductorNombre,
    required this.tipoVehiculo,
    required this.solicitud,
  });

  @override
  State<ConductorSearchingPassengersScreen> createState() =>
      _ConductorSearchingPassengersScreenState();
}

class _ConductorSearchingPassengersScreenState
    extends State<ConductorSearchingPassengersScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  
  Map<String, dynamic>? _selectedRequest;
  
  // Variables para la ruta al cliente
  MapboxRoute? _routeToClient;
  List<LatLng> _animatedRoutePoints = [];
  
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  late AnimationController _requestPanelController;
  late Animation<Offset> _requestPanelSlideAnimation;
  late Animation<double> _requestPanelFadeAnimation;
  
  late AnimationController _acceptButtonController;
  late Animation<double> _acceptButtonScaleAnimation;
  
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  
  // Animación de la ruta
  late AnimationController _routeAnimationController;
  late Animation<double> _routeAnimation;
  
  Timer? _autoRejectTimer;
  bool _panelExpanded = false;
  double _dragStartPosition = 0;
  double _currentDragOffset = 0;
  bool _requestProcessed = false; // Flag para evitar procesar la misma solicitud dos veces

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startLocationTracking();
    
    // Asignar la solicitud única
    _selectedRequest = widget.solicitud;
    
    // Reproducir sonido de notificación al cargar la pantalla
    _playNotificationSound();
    
    // Mostrar panel de solicitud después de que se construya el widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestPanelController.forward();
        
        // Iniciar temporizador de auto-rechazo
        _timerController.reset();
        _timerController.forward();
        
        _autoRejectTimer = Timer(const Duration(seconds: 30), () {
          if (mounted && _selectedRequest != null && !_requestProcessed) {
            print('⏰ Auto-rechazando solicitud por timeout');
            _rejectRequest();
          }
        });
        
        // Obtener y mostrar la ruta al cliente
        _fetchRouteToClient();
      }
    });
  }
  
  /// Reproducir sonido de notificación de nueva solicitud
  Future<void> _playNotificationSound() async {
    try {
      print('🔊 Reproduciendo sonido de solicitud...');
      await SoundService.playRequestNotification();
    } catch (e) {
      print('❌ Error reproduciendo sonido: $e');
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseAnimationController.dispose();
    _requestPanelController.dispose();
    _acceptButtonController.dispose();
    _timerController.dispose();
    _routeAnimationController.dispose();
    _autoRejectTimer?.cancel();
    
    // Desactivar disponibilidad al salir sin aceptar viaje
    _setDriverUnavailable();
    
    super.dispose();
  }
  
  Future<void> _setDriverUnavailable() async {
    try {
      await ConductorService.actualizarDisponibilidad(
        conductorId: widget.conductorId,
        disponible: false,
      );
    } catch (e) {
      print('Error desactivando disponibilidad: $e');
    }
  }

  void _setupAnimations() {
    // Animación de pulso para el marcador del conductor (más suave)
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    // Animación del panel de solicitud (más fluida)
    _requestPanelController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _requestPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _requestPanelController,
      curve: Curves.easeOutCubic,
    ));
    
    _requestPanelFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _requestPanelController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    // Animación del botón de aceptar (efecto de pulso)
    _acceptButtonController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _acceptButtonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _acceptButtonController,
      curve: Curves.easeInOut,
    ));

    // Temporizador para auto-rechazar solicitud (30 segundos)
    _timerController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    
    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _timerController,
      curve: Curves.linear,
    ));

    // Animación de la ruta hacia el cliente
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _routeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _routeAnimation.addListener(() {
      if (!mounted || _routeToClient == null) return;
      final totalPoints = _routeToClient!.geometry.length;
      final animatedCount = (totalPoints * _routeAnimation.value).round().clamp(0, totalPoints);
      if (animatedCount > 0) {
        setState(() {
          _animatedRoutePoints = _routeToClient!.geometry.sublist(0, animatedCount);
        });
      }
    });
  }

  Future<void> _startLocationTracking() async {
    try {
      print('📍 Iniciando tracking de ubicación...');
      
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Servicio de ubicación deshabilitado');
        _showError('Por favor activa el GPS en tu dispositivo');
        // Usar ubicación por defecto para pruebas
        if (mounted) {
          setState(() {
            _currentLocation = const LatLng(4.6097, -74.0817); // Bogotá
          });
        }
        // Mover mapa después de que se haya construido
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentLocation!, 15);
          }
        });
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Permiso actual: $permission');
      
      if (permission == LocationPermission.denied) {
        print('📍 Solicitando permisos...');
        permission = await Geolocator.requestPermission();
        print('📍 Permiso otorgado: $permission');
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Permisos denegados permanentemente');
        _showError('Permisos de ubicación denegados. Habilítalos en configuración.');
        // Usar ubicación por defecto
        if (mounted) {
          setState(() {
            _currentLocation = const LatLng(4.6097, -74.0817);
          });
        }
        // Mover mapa después de que se haya construido
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentLocation!, 15);
          }
        });
        return;
      }

      if (permission == LocationPermission.denied) {
        print('❌ Permisos denegados');
        _showError('Se necesitan permisos de ubicación');
        // Usar ubicación por defecto
        if (mounted) {
          setState(() {
            _currentLocation = const LatLng(4.6097, -74.0817);
          });
        }
        // Mover mapa después de que se haya construido
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentLocation!, 15);
          }
        });
        return;
      }

      print('✅ Obteniendo ubicación actual...');
      // Obtener ubicación actual con timeout más largo para emuladores
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30), // Timeout más largo
      );

      print('✅ Ubicación obtenida: ${position.latitude}, ${position.longitude}');
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }

      // Centrar mapa en ubicación actual después de que se haya construido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(_currentLocation!, 15);
          // Obtener ruta hacia el cliente
          _fetchRouteToClient();
        }
      });

      // Escuchar cambios de ubicación
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Actualizar cada 10 metros
          // No usar timeLimit en streams para evitar timeouts constantes
        ),
      ).listen(
        (Position position) {
          if (!mounted) return;
          
          print('📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}');
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });

          // Actualizar ubicación en el servidor
          TripRequestSearchService.updateLocation(
            conductorId: widget.conductorId,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        },
        onError: (error) {
          print('❌ Error en stream de ubicación: $error');
        },
      );
    } catch (e) {
      print('❌ Error crítico obteniendo ubicación: $e');
      _showError('Error obteniendo ubicación. Usando ubicación de prueba.');
      // Usar ubicación por defecto para que la app siga funcionando
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(4.6097, -74.0817); // Bogotá
        });
      }
      // Mover mapa después de que se haya construido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(_currentLocation!, 15);
        }
      });
    }
  }



  /// Obtener la ruta desde el conductor hasta el cliente
  Future<void> _fetchRouteToClient() async {
    if (_currentLocation == null || _selectedRequest == null) return;
    
    try {
      final clienteLat = double.parse(_selectedRequest!['latitud_origen'].toString());
      final clienteLng = double.parse(_selectedRequest!['longitud_origen'].toString());
      
      final route = await MapboxService.getRoute(
        waypoints: [
          _currentLocation!,
          LatLng(clienteLat, clienteLng),
        ],
      );
      
      if (route != null && mounted) {
        setState(() {
          _routeToClient = route;
        });
        
        // Ajustar mapa para mostrar toda la ruta
        _fitMapToRoute();
        
        // Iniciar animación de la ruta
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          _routeAnimationController.forward();
        }
      }
    } catch (e) {
      print('❌ Error obteniendo ruta al cliente: $e');
    }
  }

  /// Ajustar el mapa para mostrar toda la ruta
  void _fitMapToRoute() {
    if (_routeToClient == null || _routeToClient!.geometry.isEmpty) return;
    
    try {
      final bounds = LatLngBounds.fromPoints(_routeToClient!.geometry);
      
      // Añadir padding para que los marcadores sean visibles
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 350),
        ),
      );
    } catch (e) {
      print('❌ Error ajustando mapa: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _acceptRequest() async {
    if (_selectedRequest == null || _requestProcessed) return;

    // Marcar como procesada para evitar doble procesamiento
    _requestProcessed = true;
    
    // Detener temporizador
    _autoRejectTimer?.cancel();
    _timerController.stop();
    
    // Detener cualquier sonido
    SoundService.stopSound();
    
    // Guardar referencia a la solicitud antes de limpiarla
    final solicitudData = _selectedRequest!;
    
    // Limpiar la solicitud inmediatamente para evitar re-procesamiento
    setState(() {
      _selectedRequest = null;
    });

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final result = await TripRequestSearchService.acceptRequest(
      solicitudId: solicitudData['id'],
      conductorId: widget.conductorId,
    );

    if (!mounted) return;
    Navigator.pop(context); // Cerrar loading

    if (result['success'] == true) {
      // Marcar solicitud como aceptada en el servicio
      TripRequestSearchService.markRequestAsProcessed(solicitudData['id']);
      
      // Navegar a la pantalla de navegación activa (ruta)
      final origenLat = double.tryParse(solicitudData['latitud_origen']?.toString() ?? '0') ?? 0;
      final origenLng = double.tryParse(solicitudData['longitud_origen']?.toString() ?? '0') ?? 0;
      final destinoLat = double.tryParse(solicitudData['latitud_destino']?.toString() ?? '0') ?? 0;
      final destinoLng = double.tryParse(solicitudData['longitud_destino']?.toString() ?? '0') ?? 0;

      // Algunos backends devuelven viaje_id al aceptar
      final viajeId = int.tryParse(result['viaje_id']?.toString() ?? '0');

      if (!mounted) return;
      
      // Reemplazar TODA la pila de navegación con la pantalla de viaje activo
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorActiveTripScreen(
            conductorId: widget.conductorId,
            solicitudId: solicitudData['id'] as int,
            viajeId: (viajeId != null && viajeId > 0) ? viajeId : null,
            origenLat: origenLat,
            origenLng: origenLng,
            destinoLat: destinoLat,
            destinoLng: destinoLng,
            direccionOrigen: solicitudData['direccion_origen'] ?? '',
            direccionDestino: solicitudData['direccion_destino'] ?? '',
            clienteNombre: solicitudData['cliente_nombre']?.toString(),
          ),
        ),
        (route) => false, // Eliminar todas las pantallas anteriores
      );
    } else {
      // Error al aceptar (otro conductor la tomó primero)
      // Marcar como procesada para no volver a mostrarla
      TripRequestSearchService.markRequestAsProcessed(solicitudData['id']);
      
      _showError(result['message'] ?? 'Solicitud ya no disponible');
      
      // Esperar un momento para que el usuario vea el mensaje
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted) {
        // Regresar al home para buscar otra solicitud
        Navigator.pop(context);
      }
    }
  }

  Future<void> _rejectRequest() async {
    if (_selectedRequest == null || _requestProcessed) return;

    // Marcar como procesada para evitar doble procesamiento
    _requestProcessed = true;
    
    // Detener temporizador
    _autoRejectTimer?.cancel();
    _timerController.stop();
    
    // Detener cualquier sonido que se esté reproduciendo
    SoundService.stopSound();
    
    // Guardar referencia a la solicitud antes de limpiarla
    final solicitudData = _selectedRequest!;
    
    // Limpiar la solicitud inmediatamente
    setState(() {
      _selectedRequest = null;
    });

    // Marcar como rechazada para no volver a mostrarla a ESTE conductor
    TripRequestSearchService.markRequestAsProcessed(solicitudData['id']);
    
    // Rechazar en el backend (opcional - para estadísticas)
    await TripRequestSearchService.rejectRequest(
      solicitudId: solicitudData['id'],
      conductorId: widget.conductorId,
      motivo: 'Conductor rechazó',
    );

    if (!mounted) return;

    print('❌ Solicitud rechazada, regresando al home para buscar otra...');
    
    // SIEMPRE regresar al home después de rechazar
    // Esto permite que el servicio busque la siguiente solicitud disponible
    Navigator.pop(context);
  }

  /// Obtener color del temporizador según segundos restantes
  Color _getTimerColor(int seconds) {
    if (seconds <= 5) {
      return const Color(0xFFF44336); // Rojo - urgente
    } else if (seconds <= 10) {
      return const Color(0xFFFF9800); // Naranja - advertencia
    } else if (seconds <= 20) {
      return AppColors.primary; // Azul - normal
    } else {
      return const Color(0xFF4CAF50); // Verde - tiempo suficiente
    }
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'es_CO');
    return formatter.format(price.round());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Mapa
          _buildMap(),
          
          // Panel inferior con solicitud (si hay)
          if (_selectedRequest != null) _buildRequestPanel(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: _rejectRequest,
              child: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Buscando pasajeros',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMap() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (_currentLocation == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFFF00)),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation!,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        // Tiles oscuros
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.example.ping_go',
        ),
        
        // ========== RUTA 3D ESTILO UBER/DIDI CONDUCTOR -> CLIENTE ==========
        // Usando Route3DOverlay para capas de ruta 3D
        if (_animatedRoutePoints.length > 1)
          ...Route3DOverlay(
            routePoints: _animatedRoutePoints,
            isDark: isDark,
            strokeWidth: 6.0,
          ).buildLayers(),
        
        // Indicador de dirección (flecha animada al inicio de la ruta)
        if (_animatedRoutePoints.length > 2)
          Route3DOverlay(
            routePoints: _animatedRoutePoints,
            isDark: isDark,
          ).buildDirectionArrow() ?? const SizedBox.shrink(),
        
        // Marcador del conductor con pulso mejorado
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLocation!,
              width: 100,
              height: 100,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulso exterior suave
                      Container(
                        width: 70 * _pulseAnimation.value,
                        height: 70 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha:
                            0.2 / _pulseAnimation.value,
                          ),
                        ),
                      ),
                      // Anillo intermedio
                      Container(
                        width: 50 * _pulseAnimation.value,
                        height: 50 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha:
                            0.3 / _pulseAnimation.value,
                          ),
                        ),
                      ),
                      // Sombra del marcador
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      // Círculo principal con borde
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 3.5,
                          ),
                        ),
                      ),
                      // Ícono del conductor
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        
        // Marcador de solicitud actual (si hay)
        if (_selectedRequest != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  double.parse(_selectedRequest!['latitud_origen'].toString()),
                  double.parse(_selectedRequest!['longitud_origen'].toString()),
                ),
                width: 80,
                height: 80,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulso de fondo
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 60 * _pulseAnimation.value,
                            height: 60 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha:
                                0.3 / _pulseAnimation.value,
                              ),
                            ),
                          );
                        },
                      ),
                      // Pin del pasajero
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_pin_circle_rounded,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                          // Sombra en el suelo
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 25,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRequestPanel() {
    if (_selectedRequest == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final distanciaKm = double.tryParse(
      _selectedRequest!['distancia_km']?.toString() ?? '0',
    ) ?? 0;
    
    final precioEstimado = double.tryParse(
      _selectedRequest!['precio_estimado']?.toString() ?? '0',
    ) ?? 0;
    
    final duracionMinutos = int.tryParse(
      _selectedRequest!['duracion_minutos']?.toString() ?? '0',
    ) ?? 0;

    // Calcular distancia del conductor al punto de recogida del cliente
    double distanciaConductorCliente = 0;
    int etaMinutos = 0; // Tiempo estimado de llegada al cliente
    
    if (_currentLocation != null) {
      final clienteLat = double.parse(_selectedRequest!['latitud_origen'].toString());
      final clienteLng = double.parse(_selectedRequest!['longitud_origen'].toString());
      
      const Distance distance = Distance();
      distanciaConductorCliente = distance.as(
        LengthUnit.Kilometer,
        LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
        LatLng(clienteLat, clienteLng),
      );
      
      // Usar el tiempo de la ruta si está disponible, sino estimar
      if (_routeToClient != null) {
        etaMinutos = _routeToClient!.durationMinutes.ceil();
      } else {
        // Estimar: ~2 min por km en ciudad
        etaMinutos = (distanciaConductorCliente * 2).ceil();
      }
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _requestPanelSlideAnimation,
        child: FadeTransition(
          opacity: _requestPanelFadeAnimation,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: GestureDetector(
                onVerticalDragStart: (details) {
                  if (!mounted) return;
                  
                  setState(() {
                    _dragStartPosition = details.localPosition.dy;
                  });
                },
                onVerticalDragUpdate: (details) {
                  if (!mounted) return;
                  
                  setState(() {
                    _currentDragOffset = details.localPosition.dy - _dragStartPosition;
                  });
                },
                onVerticalDragEnd: (details) {
                  if (!mounted) return;
                  
                  // Si el usuario arrastra hacia arriba (velocidad negativa) o el offset es significativo
                  if (details.primaryVelocity != null) {
                    final v = details.primaryVelocity!;
                    if (v < -300 || _currentDragOffset < -50) {
                      // Expandir
                      setState(() {
                        _panelExpanded = true;
                        _currentDragOffset = 0;
                      });
                    } else if (v > 300 || _currentDragOffset > 50) {
                      // Contraer
                      setState(() {
                        _panelExpanded = false;
                        _currentDragOffset = 0;
                      });
                    } else {
                      // Reset si no hay suficiente movimiento
                      setState(() {
                        _currentDragOffset = 0;
                      });
                    }
                  } else {
                    setState(() {
                      _currentDragOffset = 0;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark 
                        ? [
                            AppColors.darkCard.withValues(alpha: 0.85),
                            AppColors.darkCard.withValues(alpha: 0.98),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.98),
                          ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, -15),
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                child: SafeArea(
                  top: false, // No aplicar SafeArea arriba para evitar espacio extra
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header con drag handle y temporizador mejorado
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Temporizador circular animado mejorado
                            AnimatedBuilder(
                              animation: _timerAnimation,
                              builder: (context, child) {
                                final seconds = (_timerAnimation.value * 30).ceil();
                                final timerColor = _getTimerColor(seconds);
                                return Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        timerColor.withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: timerColor.withValues(alpha: 0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: timerColor.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Círculo de progreso
                                      SizedBox(
                                        width: 46,
                                        height: 46,
                                        child: CircularProgressIndicator(
                                          value: _timerAnimation.value,
                                          strokeWidth: 3.5,
                                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                                          valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),
                                      // Texto del temporizador con animación de escala cuando es urgente
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 1.0, end: seconds <= 5 ? 1.15 : 1.0),
                                        duration: const Duration(milliseconds: 200),
                                        builder: (context, scale, child) {
                                          return Transform.scale(
                                            scale: scale,
                                            child: Text(
                                              '$seconds',
                                              style: TextStyle(
                                                color: timerColor,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Drag handle con efecto glass
                            Column(
                              children: [
                                Container(
                                  width: 45,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark 
                                        ? [
                                            Colors.white.withValues(alpha: 0.2),
                                            Colors.white.withValues(alpha: 0.4),
                                            Colors.white.withValues(alpha: 0.2),
                                          ]
                                        : [
                                            Colors.grey.withValues(alpha: 0.3),
                                            Colors.grey.withValues(alpha: 0.5),
                                            Colors.grey.withValues(alpha: 0.3),
                                          ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    color: isDark 
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  child: Text(_panelExpanded ? 'Desliza abajo' : 'Desliza arriba'),
                                ),
                              ],
                            ),
                            // Badge de nueva solicitud con efecto glow
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.25),
                                    AppColors.primary.withValues(alpha: 0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Indicador pulsante
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.6 * (2 - _pulseAnimation.value)),
                                              blurRadius: 6 * _pulseAnimation.value,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '¡Nuevo viaje!',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        
                        // Contenido contraído (SIEMPRE VISIBLE)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: 1.0,
                          child: Column(
                            children: [
                              // Tarjeta de precio premium con efecto glass
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.18),
                                      AppColors.blue700.withValues(alpha: 0.12),
                                      AppColors.primary.withValues(alpha: 0.08),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Fila de precio
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$',
                                          style: TextStyle(
                                            color: AppColors.primary.withValues(alpha: 0.85),
                                            fontSize: 26,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: precioEstimado),
                                          duration: const Duration(milliseconds: 800),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, value, child) {
                                            return Text(
                                              _formatPrice(value),
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 44,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -2,
                                                height: 1,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Text(
                                            'COP',
                                            style: TextStyle(
                                              color: AppColors.primary.withValues(alpha: 0.65),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Divider con gradiente
                                    Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            AppColors.primary.withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Info chips
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildInfoChip(
                                          icon: Icons.route_rounded,
                                          value: '${distanciaKm.toStringAsFixed(1)} km',
                                          color: AppColors.primary,
                                          isDark: isDark,
                                        ),
                                        Container(
                                          width: 1,
                                          height: 20,
                                          margin: const EdgeInsets.symmetric(horizontal: 16),
                                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.3),
                                        ),
                                        _buildInfoChip(
                                          icon: Icons.schedule_rounded,
                                          value: '$duracionMinutos min',
                                          color: AppColors.primary,
                                          isDark: isDark,
                                        ),
                                        Container(
                                          width: 1,
                                          height: 20,
                                          margin: const EdgeInsets.symmetric(horizontal: 16),
                                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.3),
                                        ),
                                        _buildInfoChip(
                                          icon: Icons.navigation_rounded,
                                          value: etaMinutos > 0 ? '$etaMinutos min' : '${distanciaConductorCliente.toStringAsFixed(1)} km',
                                          color: const Color(0xFF4CAF50),
                                          label: etaMinutos > 0 ? 'hasta cliente' : 'distancia',
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              
                              // Botones de acción mejorados
                              Row(
                                children: [
                                  // Botón de rechazar con efecto glass
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isDark 
                                          ? [
                                              const Color(0xFF3A3A3A),
                                              const Color(0xFF2A2A2A),
                                            ]
                                          : [
                                              Colors.grey[200]!,
                                              Colors.grey[300]!,
                                            ],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isDark 
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : Colors.grey.withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          _rejectRequest();
                                        },
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: isDark ? Colors.white : Colors.grey[700],
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Botón de aceptar premium con gradiente y animación
                                  Expanded(
                                    child: AnimatedBuilder(
                                      animation: _acceptButtonScaleAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _acceptButtonScaleAnimation.value,
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.primary,
                                              AppColors.blue700,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(18),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.5),
                                              blurRadius: 25,
                                              spreadRadius: 0,
                                              offset: const Offset(0, 8),
                                            ),
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.3),
                                              blurRadius: 50,
                                              spreadRadius: 5,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(18),
                                            onTap: () {
                                              HapticFeedback.heavyImpact();
                                              _acceptRequest();
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Text(
                                                  'Aceptar viaje',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Contenido expandido (SOLO CUANDO _panelExpanded = true)
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          crossFadeState: _panelExpanded 
                              ? CrossFadeState.showSecond 
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox.shrink(),
                          secondChild: Column(
                            children: [
                              const SizedBox(height: 16),
                              
                              // Ubicaciones: Conductor y Cliente
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark 
                                    ? const Color(0xFF2A2A2A).withValues(alpha: 0.6)
                                    : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark 
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Tu ubicación (conductor)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.navigation_rounded,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Tu ubicación',
                                                  style: TextStyle(
                                                    color: isDark 
                                                      ? Colors.white.withValues(alpha: 0.6)
                                                      : Colors.grey[600],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Conductor',
                                                  style: TextStyle(
                                                    color: isDark 
                                                      ? Colors.white.withValues(alpha: 0.9)
                                                      : Colors.grey[800],
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Separador con distancia
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.arrow_forward,
                                                  color: Color(0xFF4CAF50),
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${distanciaConductorCliente.toStringAsFixed(1)} km',
                                                  style: const TextStyle(
                                                    color: Color(0xFF4CAF50),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Ubicación del cliente
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.person_pin_circle,
                                              color: Color(0xFF2196F3),
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Cliente',
                                                  style: TextStyle(
                                                    color: isDark 
                                                      ? Colors.white.withValues(alpha: 0.6)
                                                      : Colors.grey[600],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Recoger aquí',
                                                  style: TextStyle(
                                                    color: isDark 
                                                      ? Colors.white.withValues(alpha: 0.9)
                                                      : Colors.grey[800],
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Temporizador de auto-rechazo
                              AnimatedBuilder(
                                animation: _timerAnimation,
                                builder: (context, child) {
                                  final secondsLeft = (_timerAnimation.value * 30).ceil();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: secondsLeft <= 10
                                          ? Colors.red.withValues(alpha: 0.15)
                                          : isDark 
                                            ? const Color(0xFF2A2A2A).withValues(alpha: 0.5)
                                            : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: secondsLeft <= 10
                                            ? Colors.red.withValues(alpha: 0.3)
                                            : isDark 
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : Colors.grey.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          color: secondsLeft <= 10
                                              ? Colors.red
                                              : AppColors.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                secondsLeft <= 10
                                                    ? '⚠️ Solicitud expirando'
                                                    : 'Tiempo para responder',
                                                style: TextStyle(
                                                  color: secondsLeft <= 10
                                                      ? Colors.red
                                                      : isDark 
                                                        ? Colors.white.withValues(alpha: 0.7)
                                                        : Colors.grey[600],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: LinearProgressIndicator(
                                                  value: _timerAnimation.value,
                                                  backgroundColor: isDark 
                                                    ? Colors.white.withValues(alpha: 0.1)
                                                    : Colors.grey.withValues(alpha: 0.2),
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    secondsLeft <= 10
                                                        ? Colors.red
                                                        : AppColors.primary,
                                                  ),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: secondsLeft <= 10
                                                ? Colors.red
                                                : AppColors.primary.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${secondsLeft}s',
                                            style: TextStyle(
                                              color: secondsLeft <= 10
                                                  ? Colors.white
                                                  : AppColors.primary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Direcciones
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark 
                                    ? const Color(0xFF2A2A2A).withValues(alpha: 0.6)
                                    : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark 
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _buildLocationInfo(
                                      icon: Icons.my_location,
                                      iconColor: const Color(0xFF4CAF50),
                                      label: 'Recoger en',
                                      value: _selectedRequest!['direccion_origen'] ?? 'Sin dirección',
                                      isDark: isDark,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 18),
                                          Column(
                                            children: List.generate(
                                              3,
                                              (index) => Container(
                                                margin: const EdgeInsets.only(bottom: 3),
                                                width: 3,
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: isDark 
                                                    ? Colors.white.withValues(alpha: 0.3)
                                                    : Colors.grey.withValues(alpha: 0.4),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildLocationInfo(
                                      icon: Icons.location_on,
                                      iconColor: AppColors.primary,
                                      label: 'Dejar en',
                                      value: _selectedRequest!['direccion_destino'] ?? 'Sin dirección',
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// Widget para mostrar info chips (distancia, tiempo, etc)
  Widget _buildInfoChip({
    required IconData icon,
    required String value,
    required Color color,
    String? label,
    bool isDark = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.95) : Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildLocationInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isDark = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark 
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

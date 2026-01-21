import 'dart:async';
import '../../services/conductor_profile_service.dart';
import '../../services/conductor_service.dart';
import '../../../../global/services/auth/user_service.dart';

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../theme/app_colors.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/dispute_service.dart';
import '../../providers/conductor_provider.dart';
import '../../services/trip_request_search_service.dart';
import '../../services/demand_zone_service.dart';
import '../../models/demand_zone_model.dart';
import 'conductor_searching_passengers_screen.dart';
import 'driver_onboarding_screen.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/demand_zones_overlay.dart';
import '../widgets/common/radar_indicator.dart';
import 'package:intl/intl.dart';
import '../../../user/presentation/widgets/home/map_loading_shimmer.dart';

/// Pantalla principal del conductor - Diseño profesional y minimalista
/// Inspirado en Uber/Didi pero con identidad propia
class ConductorHomeScreen extends StatefulWidget {
  final Map<String, dynamic> conductorUser;

  const ConductorHomeScreen({super.key, required this.conductorUser});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();

  // Flag para prevenir setState después de dispose
  bool _isDisposed = false;

  /// Safe setState that checks if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  geo.Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isMapReady = false;
  bool _isOnline = false;
  StreamSubscription<geo.Position>? _positionStream;

  // Variables para búsqueda de solicitudes
  bool _isSearchingRequests = false;
  String _searchStatus = 'Buscando solicitudes cercanas...';

  // Variables para zonas de demanda (surge pricing)
  List<DemandZone> _demandZones = [];
  bool _showDemandZones = false;
  bool _showDemandLegend = false;
  DemandZone? _selectedZone;

  // Variables para disputa activa
  bool _hasActiveDispute = false;
  DisputaData? _activeDispute;
  
  // Info Empresa
  Map<String, dynamic>? _companyInfo;
  
  // Estadísticas del día
  int _viajesHoy = 0;
  double _gananciasHoy = 0.0;

  late AnimationController _pulseController;
  late AnimationController _connectionController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _requestLocationPermission();
    _checkActiveDispute(); // Verificar disputa activa al inicio

    // Marcar mapa como listo
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isMapReady = true;
        });
        debugPrint('✅ Mapa listo');

        // Verificar onboarding del conductor
        _checkDriverOnboarding();
        _loadCompanyInfo();
        _loadDailyStats();
      }
    });
  }

  Future<void> _loadDailyStats() async {
    try {
      final conductorId = widget.conductorUser['id'];
      if (conductorId == null) return;
      
      final stats = await ConductorService.getEstadisticas(int.parse(conductorId.toString()));
      
      if (stats.isNotEmpty && mounted) {
        _safeSetState(() {
          _viajesHoy = stats['viajes_hoy'] ?? 0;
          _gananciasHoy = (stats['ganancias_hoy'] ?? 0).toDouble();
        });
        debugPrint('📊 Estadísticas del día: $_viajesHoy viajes, \$$_gananciasHoy');
      }
    } catch (e) {
      debugPrint('Error loading daily stats: $e');
    }
  }

  Future<void> _loadCompanyInfo() async {
    try {
      final empresaId = widget.conductorUser['empresa_id'];
      if (empresaId != null) {
        final info = await ConductorProfileService.getCompanyDetails(int.parse(empresaId.toString()));
        if (info != null && mounted) {
          _safeSetState(() {
            _companyInfo = info;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading company info: $e');
    }
  }

  /// Verifica si el conductor ha visto el onboarding
  Future<void> _checkDriverOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool onboardingSeen =
          prefs.getBool('driver_onboarding_seen_v1') ?? false;

      if (!onboardingSeen && mounted) {
        debugPrint('🆕 Nuevo conductor detectado, mostrando onboarding...');
        // Mostrar onboarding encima el home
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const DriverOnboardingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutQuart;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error verificando onboarding: $e');
    }
  }

  /// Verifica si el conductor tiene una disputa activa
  Future<void> _checkActiveDispute() async {
    try {
      final conductorId = widget.conductorUser['id'];
      if (conductorId == null) return;

      debugPrint('🔍 Verificando disputa activa para conductor $conductorId');

      final result = await DisputeService().checkDisputeStatus(conductorId);

      if (result.tieneDisputa && result.disputa != null && mounted) {
        debugPrint('⚠️ ¡Disputa activa encontrada! ID: ${result.disputa!.id}');
        _safeSetState(() {
          _hasActiveDispute = true;
          _activeDispute = result.disputa;
        });

        // Mostrar overlay de disputa después de que el widget esté construido
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showDisputeAlert();
          }
        });
      } else {
        debugPrint('✅ No hay disputas activas');
      }
    } catch (e) {
      debugPrint('❌ Error verificando disputa: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        debugPrint('⏸️ App pausada');
        break;

      case AppLifecycleState.detached:
        debugPrint('🔌 App desconectada');
        break;

      case AppLifecycleState.resumed:
        debugPrint('✅ App en foreground');
        // Actualizar posición del mapa si es necesario
        if (_currentPosition != null && mounted) {
          _centerMapOnLocation(_currentPosition!);
        }
        break;

      case AppLifecycleState.hidden:
        debugPrint('👁️ App oculta');
        break;
    }
  }

  void _initializeAnimations() {
    // Animación de pulso suave para indicador online
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de rotación para el icono de búsqueda
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.linear));

    // Animación de escala para transiciones
    _connectionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _connectionController,
      curve: Curves.elasticOut,
    );

    // Animación de fade para elementos UI
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Animación de slide para panel inferior
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Iniciar animaciones de entrada
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  Future<void> _requestLocationPermission() async {
    try {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();

      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        _safeSetState(() => _isLoadingLocation = false);
        return;
      }

      if (permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always) {
        await _getCurrentLocation();
      }
    } catch (e) {
      debugPrint('Error al solicitar permisos de ubicación: $e');
      _safeSetState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      if (_isDisposed) return;

      _safeSetState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Centrar mapa en la ubicación actual
      _centerMapOnLocation(position);

      // Iniciar seguimiento de ubicación en tiempo real
      _startLocationTracking();

      // Cargar zonas de demanda inmediatamente (para mostrar antes de conectarse)
      _startDemandZonesUpdates();
    } catch (e) {
      debugPrint('Error al obtener ubicación: $e');
      _safeSetState(() => _isLoadingLocation = false);
    }
  }

  void _centerMapOnLocation(geo.Position position) {
    try {
      _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
    } catch (e) {
      debugPrint('Error al centrar mapa: $e');
    }
  }

  void _startLocationTracking() {
    final locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    _positionStream =
        geo.Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          (geo.Position position) {
            _safeSetState(() => _currentPosition = position);

            // Actualizar mapa con debounce
            _debouncedUpdateMapLocation(position);
          },
          onError: (error) {
            debugPrint('❌ Error en stream de ubicación: $error');
          },
        );
  }

  void _debouncedUpdateMapLocation(geo.Position position) {
    // Solo actualizar si el mapa está listo y la app está en foreground
    if (!_isMapReady || !mounted) return;

    _centerMapOnLocation(position);
  }

  void _startSearchingRequests() {
    if (_currentPosition == null || _isDisposed) {
      debugPrint('❌ No hay ubicación actual para buscar solicitudes');
      return;
    }

    _safeSetState(() {
      _isSearchingRequests = true;
      _searchStatus = 'Buscando solicitudes cercanas...';
    });

    TripRequestSearchService.startSearching(
      conductorId: widget.conductorUser['id'] as int,
      currentLat: _currentPosition!.latitude,
      currentLng: _currentPosition!.longitude,
      onRequestsFound: _onRequestsFound,
      onError: _onSearchError,
    );
  }

  void _stopSearchingRequests() {
    TripRequestSearchService.stopSearching();

    _safeSetState(() {
      _isSearchingRequests = false;
      _searchStatus = 'Buscando solicitudes cercanas...';
    });
  }

  void _onRequestsFound(List<Map<String, dynamic>> requests) {
    if (_isDisposed || !mounted || !_isOnline) return;

    if (requests.isNotEmpty) {
      // Hay solicitudes disponibles - mostrar LA PRIMERA solicitud
      debugPrint(
        '🎯 ${requests.length} solicitudes encontradas! Mostrando la primera...',
      );

      // Detener búsqueda temporalmente
      _stopSearchingRequests();

      // Navegar a pantalla de solicitud con LA PRIMERA solicitud únicamente
      // Lógica tipo Uber/InDrive: muestra una a la vez
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorSearchingPassengersScreen(
            conductorId: widget.conductorUser['id'] as int,
            conductorNombre:
                widget.conductorUser['nombre']?.toString() ?? 'Conductor',
            tipoVehiculo:
                widget.conductorUser['tipo_vehiculo']?.toString() ?? 'Sedan',
            solicitud: requests.first, // SOLO LA PRIMERA solicitud
          ),
        ),
      ).then((result) {
        // Cuando regresa de la pantalla de solicitud
        // SIEMPRE vuelve al home después de aceptar/rechazar
        if (!_isDisposed && mounted && _isOnline) {
          // Reiniciar búsqueda para encontrar la siguiente solicitud
          debugPrint('🔄 Reiniciando búsqueda de solicitudes...');
          _startSearchingRequests();
        }
      });
    } else {
      // No hay solicitudes, continuar buscando
      _safeSetState(() {
        _searchStatus = 'Buscando solicitudes cercanas...';
      });
    }
  }

  void _onSearchError(String error) {
    if (_isDisposed || !mounted) return;

    debugPrint('❌ Error en búsqueda: $error');
    _safeSetState(() {
      _searchStatus = 'Error de conexión. Reintentando...';
    });
  }

  // ========== MÉTODOS DE ZONAS DE DEMANDA ==========

  /// Iniciar actualizaciones de zonas de demanda
  void _startDemandZonesUpdates() {
    if (_currentPosition == null) {
      debugPrint('❌ No hay ubicación para cargar zonas de demanda');
      return;
    }

    debugPrint('🔥 Iniciando carga de zonas de demanda...');

    DemandZoneService.startAutoRefresh(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      onZonesUpdated: (zones) {
        if (!_isDisposed && mounted) {
          _safeSetState(() {
            _demandZones = zones;
          });
          debugPrint('🔥 ${zones.length} zonas de demanda actualizadas');
        }
      },
      onError: (error) {
        debugPrint('❌ Error al obtener zonas de demanda: $error');
      },
    );
  }

  /// Manejar tap en zona de demanda
  void _onDemandZoneTap(DemandZone zone) {
    _safeSetState(() {
      _selectedZone = zone;
    });

    // Mostrar información de la zona
    HapticFeedback.selectionClick();
    debugPrint('📍 Zona seleccionada: ${zone.demandLabel} - ${zone.surgeText}');
  }

  /// Cerrar información de zona seleccionada
  void _closeZoneInfo() {
    _safeSetState(() {
      _selectedZone = null;
    });
  }

  /// Navegar a una zona de demanda
  void _navigateToZone(DemandZone zone) {
    _mapController.move(LatLng(zone.centerLat, zone.centerLng), 16.0);
    _closeZoneInfo();
    HapticFeedback.mediumImpact();
  }

  /// Toggle de visualización de zonas de demanda
  void _toggleDemandZonesVisibility() {
    _safeSetState(() {
      _showDemandZones = !_showDemandZones;
    });
    HapticFeedback.lightImpact();
  }

  /// Toggle de leyenda de zonas de demanda
  void _toggleDemandLegend() {
    _safeSetState(() {
      _showDemandLegend = !_showDemandLegend;
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de ubicación requerido'),
        content: const Text(
          'La aplicación necesita acceso a tu ubicación para funcionar correctamente. '
          'Por favor, habilita los permisos de ubicación en la configuración.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              geo.Geolocator.openAppSettings();
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  void _toggleOnlineStatus() async {
    final conductorId = widget.conductorUser['id'] as int;
    
    if (!_isOnline) {
      // Conectarse: Actualizar en backend y luego iniciar búsqueda
      try {
        // Primero actualizar en el backend
        final success = await ConductorService.actualizarDisponibilidad(
          conductorId: conductorId,
          disponible: true,
          latitud: _currentPosition?.latitude,
          longitud: _currentPosition?.longitude,
        );
        
        if (!success) {
          _showStatusSnackbar('Error al conectarse. Intenta de nuevo.', Colors.red);
          return;
        }
        
        _safeSetState(() => _isOnline = true);
        _connectionController.forward();
        HapticFeedback.mediumImpact();

        // Limpiar caché de solicitudes procesadas (para permitir ver solicitudes que antes rechazó)
        TripRequestSearchService.clearProcessedRequests();

        // Iniciar búsqueda continua de solicitudes
        _startSearchingRequests();

        // Refrescar zonas de demanda al conectarse
        _startDemandZonesUpdates();

        _showStatusSnackbar(
          '¡Conectado! Buscando pasajeros...',
          AppColors.success,
        );
      } catch (e) {
        debugPrint('❌ Error al conectarse: $e');
        _showStatusSnackbar('Error de conexión: $e', Colors.red);
      }
    } else {
      // Desconectarse: Actualizar en backend y detener búsqueda
      try {
        // Primero actualizar en el backend
        final success = await ConductorService.actualizarDisponibilidad(
          conductorId: conductorId,
          disponible: false,
          latitud: _currentPosition?.latitude,
          longitud: _currentPosition?.longitude,
        );
        
        if (!success) {
          _showStatusSnackbar('Error al desconectarse. Intenta de nuevo.', Colors.red);
          return;
        }
        
        _safeSetState(() => _isOnline = false);
        _connectionController.reverse();
        HapticFeedback.lightImpact();

        // Detener búsqueda de solicitudes
        _stopSearchingRequests();

        // Las zonas de demanda siguen visibles cuando está offline para consistencia
        // No detenemos DemandZoneService.stopAutoRefresh() aquí

        // Limpiar caché de solicitudes procesadas
        TripRequestSearchService.clearProcessedRequests();

        _showStatusSnackbar('Estás fuera de línea', Colors.grey);
      } catch (e) {
        debugPrint('❌ Error al desconectarse: $e');
        _showStatusSnackbar('Error de conexión: $e', Colors.red);
      }
    }
  }

  void _showStatusSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isOnline ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _connectionController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _positionStream?.cancel();
    _mapController.dispose();

    // Detener búsqueda si está activa
    _stopSearchingRequests();

    // Detener actualización de zonas de demanda
    DemandZoneService.stopAutoRefresh();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      drawer: ConductorDrawer(conductorUser: widget.conductorUser),
      body: Stack(
        children: [
          // Mapa de fondo
          _buildMap(),

          // Overlay con controles
          _buildOverlay(),
        ],
      ),
    );
  }

  // Obtener nombre del conductor
  String get _conductorName {
    final nombre = widget.conductorUser['nombre']?.toString() ?? '';
    if (nombre.isNotEmpty) {
      // Obtener solo el primer nombre
      final parts = nombre.split(' ');
      return parts.first;
    }
    return 'Conductor';
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        flexibleSpace: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Contenedor principal con efecto glass
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.7)),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: (isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.5)),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Logo con efecto glass
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: (isDark
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : AppColors.primary.withValues(
                                            alpha: 0.1,
                                          )),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      width: 1,
                                    ),
                                    image: _companyInfo?['logo_url'] != null
                                        ? DecorationImage(
                                            image: NetworkImage(UserService.getR2ImageUrl(_companyInfo!['logo_url']) ?? ''),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _companyInfo?['logo_url'] != null
                                      ? null
                                      : Center(
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            width: 24,
                                            height: 24,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(Icons.business, size: 24);
                                            },
                                          ),
                                        ),
                                ),
                              const SizedBox(width: 10),
                              // Saludo con nombre del conductor
                                Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_companyInfo != null) ...[
                                      Text(
                                        _conductorName,
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _companyInfo!['nombre'] ?? 'Mi Empresa',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ] else ...[
                                      Text(
                                      'Hola,',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _conductorName,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    ],
                                  ],
                                ),
                              ),
                              // Indicador de estado inline
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _isOnline
                                      ? AppColors.success.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _isOnline
                                            ? AppColors.success
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(
                                        color: _isOnline
                                            ? AppColors.success
                                            : Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
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
                  const SizedBox(width: 10),
                  // Botón de menú con efecto glass
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.7)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.5)),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.menu_rounded,
                            color: isDark ? Colors.white : Colors.grey[800],
                            size: 22,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                      ),
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

  Widget _buildMap() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Si no hay ubicación, mostrar shimmer de mapa como en cliente pasajero
    if (_isLoadingLocation) {
      return const MapLoadingShimmer();
    }

    // Si no hay posición, mostrar error
    if (_currentPosition == null) {
      return Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo obtener tu ubicación',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _requestLocationPermission,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // Mapa con flutter_map
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        initialZoom: 16.0,
        minZoom: 3.0,
        maxZoom: 18.0,
      ),
      children: [
        // Capa de tiles de Mapbox
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
        ),

        // ========== ZONAS DE DEMANDA (SURGE PRICING) ==========
        // Mostrar siempre que haya zonas (también cuando está offline para planificación)
        if (_showDemandZones && _demandZones.isNotEmpty)
          DemandZonesOverlay(
            zones: _demandZones,
            showLabels: true,
            animate: true,
            onZoneTap: _onDemandZoneTap,
          ),

        // Marcador de ubicación actual con animación - MÁS GRANDE
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo exterior animado (más grande)
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color:
                                (_isOnline
                                        ? AppColors.success
                                        : AppColors.primary)
                                    .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Halo medio (más grande)
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color:
                              (_isOnline
                                      ? AppColors.success
                                      : AppColors.primary)
                                  .withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Halo interno
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                              (_isOnline
                                      ? AppColors.success
                                      : AppColors.primary)
                                  .withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Punto central del conductor (más grande)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isOnline
                                ? [
                                    AppColors.success,
                                    AppColors.success.withGreen(160),
                                  ]
                                : [AppColors.primary, AppColors.primaryDark],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isOnline
                                          ? AppColors.success
                                          : AppColors.primary)
                                      .withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isOnline
                              ? Icons.local_taxi
                              : Icons.navigation_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Stack(
        children: [
          // Contenido principal (botones y panel)
          Column(
            children: [
              const Spacer(),

              // Botón de centrar ubicación (FAB style con glass)
              _buildCenterLocationButton(isDark),

              const SizedBox(height: 16),

              // Panel inferior con controles
              _buildBottomPanel(),
            ],
          ),

          // ========== CONTROLES DE ZONAS DE DEMANDA ==========
          // Mostrar siempre que haya zonas (también cuando está offline para consistencia)
          if (_demandZones.isNotEmpty) ...[
            // Botón para toggle de zonas y leyenda (esquina superior derecha)
            Positioned(
              top: 8,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Botón de toggle zonas
                  _buildDemandZonesToggleButton(isDark),
                  const SizedBox(height: 8),
                  // Leyenda de zonas (esquina superior derecha)
                  if (_showDemandZones)
                    DemandZoneLegend(
                      isExpanded: _showDemandLegend,
                      onToggle: _toggleDemandLegend,
                    ),
                ],
              ),
            ),
          ],

          // Tarjeta de información de zona seleccionada
          if (_selectedZone != null)
            Positioned(
              bottom: 200,
              left: 0,
              right: 0,
              child: DemandZoneInfoCard(
                zone: _selectedZone!,
                onClose: _closeZoneInfo,
                onNavigate: () => _navigateToZone(_selectedZone!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterLocationButton(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (_currentPosition != null) {
                      _centerMapOnLocation(_currentPosition!);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.5)),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                      size: 24,
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

  /// Botón para toggle de visualización de zonas de demanda
  Widget _buildDemandZonesToggleButton(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleDemandZonesVisibility,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showDemandZones
                    ? Colors.orange.withValues(alpha: isDark ? 0.3 : 0.2)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.8)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showDemandZones
                      ? Colors.orange.withValues(alpha: 0.5)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.5)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showDemandZones
                        ? Icons.local_fire_department
                        : Icons.local_fire_department_outlined,
                    color: _showDemandZones
                        ? Colors.orange
                        : (isDark ? Colors.white70 : Colors.grey[700]),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Zonas',
                    style: TextStyle(
                      color: _showDemandZones
                          ? Colors.orange
                          : (isDark ? Colors.white70 : Colors.grey[700]),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildBottomPanel() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(
              alpha: 0.95,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey.shade300)
                    .withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.05,
              ),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Estado y Estadísticas
                  _buildCompactInfoRow(theme, isDark),

                  // Divisor sutil
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.05),
                    ),
                  ),

                  // Botón de conexión animado
                  _buildConnectionButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfoRow(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila Superior: Indicador + Textos
          Row(
            children: [
              // Indicador de Estado Animado
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? AppColors.success.withValues(alpha: 0.1)
                      : theme.dividerColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isOnline
                        ? AppColors.success.withValues(alpha: 0.2)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: _isOnline
                      ? RadarIndicator(
                          key: ValueKey(_isOnline),
                          active: true,
                          size: 26,
                          color: AppColors.success,
                        )
                      : Icon(
                          Icons.wifi_off_rounded,
                          key: ValueKey(_isOnline),
                          color: theme.iconTheme.color?.withValues(alpha: 0.3),
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Texto de Estado - Expanded para usar todo el ancho disponible
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isOnline ? 'En línea' : 'Desconectado',
                        key: ValueKey(_isOnline),
                        style: TextStyle(
                          color: theme.textTheme.titleMedium?.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isOnline
                            ? 'Buscando pasajes...'
                            : 'Conéctate para trabajar',
                        key: ValueKey(_isOnline),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Fila Inferior: Estadísticas (Full Width)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniStat(theme, Icons.local_taxi_rounded, "$_viajesHoy"),
                Container(
                  height: 14,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
                _buildMiniStat(theme, Icons.attach_money_rounded, "\$${NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0).format(_gananciasHoy)}"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(ThemeData theme, IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: theme.textTheme.titleMedium?.color,
            fontFamily: 'Monospace', // Estilo numérico
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        height: 60, // Ligeramente más alto para mejor tacto
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_isOnline ? AppColors.error : AppColors.success)
                  .withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isOnline
                ? [
                    const Color(0xFFEF4444), // Red 500
                    const Color(0xFFDC2626), // Red 600
                  ]
                : [
                    AppColors.success,
                    const Color(
                      0xFF039855,
                    ), // Green 700 (Adjusted darker tone for depth) (approx)
                  ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleOnlineStatus,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isOnline
                        ? Icons.power_settings_new_rounded
                        : Icons.rocket_launch_rounded,
                    key: ValueKey(_isOnline),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _isOnline ? 'Desconectar' : 'Empezar a trabajar',
                    key: ValueKey(_isOnline),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Muestra alerta de disputa activa
  void _showDisputeAlert() {
    if (_activeDispute == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.error.withValues(alpha: 0.95),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícono animado
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      '⚠️ CUENTA SUSPENDIDA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Tienes una disputa de pago activa.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Card con estados
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.white70),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Cliente dice:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'SÍ PAGUÉ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_car,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Tú dijiste:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'NO RECIBÍ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botón para resolver
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _resolveDispute(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Confirmo que recibí el pago',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Resuelve la disputa activa
  Future<void> _resolveDispute(BuildContext dialogContext) async {
    if (_activeDispute == null) return;

    try {
      final conductorId = widget.conductorUser['id'];
      final success = await DisputeService().resolveDispute(
        disputaId: _activeDispute!.id,
        conductorId: conductorId,
      );

      if (success && mounted) {
        Navigator.pop(dialogContext);
        _safeSetState(() {
          _hasActiveDispute = false;
          _activeDispute = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¡Disputa resuelta! Tu cuenta está desbloqueada.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al resolver disputa'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error resolviendo disputa: $e');
    }
  }
}

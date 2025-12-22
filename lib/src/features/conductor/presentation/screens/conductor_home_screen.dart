import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/dispute_service.dart';
import '../../providers/conductor_provider.dart';
import '../../services/trip_request_search_service.dart';
import '../../services/demand_zone_service.dart';
import '../../models/demand_zone_model.dart';
import 'conductor_searching_passengers_screen.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/demand_zones_overlay.dart';

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
  bool _showDemandZones = true;
  bool _showDemandLegend = false;
  DemandZone? _selectedZone;

  // Variables para disputa activa
  bool _hasActiveDispute = false;
  DisputaData? _activeDispute;

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
      }
    });
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

  void _toggleOnlineStatus() {
    if (!_isOnline) {
      // Conectarse: Iniciar búsqueda de solicitudes
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
    } else {
      // Desconectarse: Detener búsqueda
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
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : AppColors.primary.withValues(
                                          alpha: 0.1,
                                        )),
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Saludo con nombre del conductor
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
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

    // Si no hay ubicación, mostrar pantalla de carga
    if (_isLoadingLocation) {
      return Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Obteniendo ubicación...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
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
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.85)),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.6)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status y estadísticas
                    _buildStatusSection(),

                    // Divisor con gradiente
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            (isDark ? Colors.white : Colors.black).withValues(
                              alpha: 0.1,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Botón de conexión
                    _buildConnectionButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Estado actual con animación mejorada
          Row(
            children: [
              // Icono de estado con efecto glass
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: _isOnline
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.success.withValues(alpha: 0.2),
                            AppColors.success.withValues(alpha: 0.1),
                          ],
                        )
                      : null,
                  color: _isOnline ? null : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isOnline
                        ? AppColors.success.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isOnline && _isSearchingRequests
                      ? AnimatedBuilder(
                          animation: _rotateAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateAnimation.value,
                              child: Icon(
                                Icons.radar_rounded,
                                color: AppColors.success,
                                size: 26,
                                key: const ValueKey('radar'),
                              ),
                            );
                          },
                        )
                      : Icon(
                          _isOnline
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          color: _isOnline ? AppColors.success : Colors.grey,
                          size: 26,
                          key: ValueKey(_isOnline ? 'online' : 'offline'),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isOnline ? 'En línea' : 'Desconectado',
                        key: ValueKey(_isOnline),
                        style: TextStyle(
                          color: theme.textTheme.titleLarge?.color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isOnline
                            ? (_isSearchingRequests
                                  ? _searchStatus
                                  : 'Listo para recibir viajes')
                            : 'Conéctate para recibir viajes',
                        key: ValueKey(
                          '$_isOnline-$_isSearchingRequests-$_searchStatus',
                        ),
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Indicador de pulso animado
              if (_isOnline)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Halo exterior animado
                          Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // Punto central
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Estadísticas rápidas con efecto glass mejorado
          Consumer<ConductorProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  _buildStatItem(
                    icon: Icons.schedule_rounded,
                    label: 'Hoy',
                    value: '0h',
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  _buildStatItem(
                    icon: Icons.local_taxi_rounded,
                    label: 'Viajes',
                    value: '0',
                    color: AppColors.accent,
                    isDark: isDark,
                  ),
                  _buildStatItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Ganado',
                    value: '\$0',
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => HapticFeedback.selectionClick(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: isDark ? 0.15 : 0.1),
                    color.withValues(alpha: isDark ? 0.08 : 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.6,
                      ),
                      fontSize: 11,
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

  Widget _buildConnectionButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.95, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleOnlineStatus,
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: _isOnline
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade600,
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.success,
                                  AppColors.success.withGreen(180),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_isOnline ? Colors.red : AppColors.success)
                                .withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              _isOnline
                                  ? Icons.power_settings_new_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(_isOnline),
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _isOnline ? 'Desconectar' : 'Empezar a trabajar',
                              key: ValueKey(_isOnline),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
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

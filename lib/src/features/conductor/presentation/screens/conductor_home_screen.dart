import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../providers/conductor_provider.dart';
import '../../services/trip_request_search_service.dart';
import 'conductor_searching_passengers_screen.dart';
import '../widgets/conductor_drawer.dart';

/// Pantalla principal del conductor - Diseño profesional y minimalista
/// Inspirado en Uber/Didi pero con identidad propia
class ConductorHomeScreen extends StatefulWidget {
  final Map<String, dynamic> conductorUser;

  const ConductorHomeScreen({
    super.key,
    required this.conductorUser,
  });

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  geo.Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isMapReady = false;
  bool _isOnline = false;
  StreamSubscription<geo.Position>? _positionStream;
  
  // Variables para búsqueda de solicitudes
  bool _isSearchingRequests = false;
  String _searchStatus = 'Buscando solicitudes cercanas...';
  
  late AnimationController _pulseController;
  late AnimationController _connectionController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _requestLocationPermission();
    
    // Marcar mapa como listo
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
        debugPrint('✅ Mapa listo');
      }
    });
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
    // Animación de pulso para el botón de conexión
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de escala para transiciones
    _connectionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _connectionController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _requestLocationPermission() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        setState(() => _isLoadingLocation = false);
        return;
      }

      if (permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always) {
        await _getCurrentLocation();
      }
    } catch (e) {
      debugPrint('Error al solicitar permisos de ubicación: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Centrar mapa en la ubicación actual
      _centerMapOnLocation(position);

      // Iniciar seguimiento de ubicación en tiempo real
      _startLocationTracking();
    } catch (e) {
      debugPrint('Error al obtener ubicación: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  void _centerMapOnLocation(geo.Position position) {
    try {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16.0,
      );
    } catch (e) {
      debugPrint('Error al centrar mapa: $e');
    }
  }

  void _startLocationTracking() {
    final locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((geo.Position position) {
      setState(() => _currentPosition = position);
      
      // Actualizar mapa con debounce
      _debouncedUpdateMapLocation(position);
    });
  }

  void _debouncedUpdateMapLocation(geo.Position position) {
    // Solo actualizar si el mapa está listo y la app está en foreground
    if (!_isMapReady || !mounted) return;
    
    _centerMapOnLocation(position);
  }

  void _startSearchingRequests() {
    if (_currentPosition == null) {
      debugPrint('❌ No hay ubicación actual para buscar solicitudes');
      return;
    }

    setState(() {
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
    
    setState(() {
      _isSearchingRequests = false;
      _searchStatus = 'Buscando solicitudes cercanas...';
    });
  }

  void _onRequestsFound(List<Map<String, dynamic>> requests) {
    if (!mounted || !_isOnline) return;

    if (requests.isNotEmpty) {
      // Hay solicitudes disponibles - mostrar LA PRIMERA solicitud
      debugPrint('🎯 ${requests.length} solicitudes encontradas! Mostrando la primera...');
      
      // Detener búsqueda temporalmente
      _stopSearchingRequests();
      
      // Navegar a pantalla de solicitud con LA PRIMERA solicitud únicamente
      // Lógica tipo Uber/InDrive: muestra una a la vez
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorSearchingPassengersScreen(
            conductorId: widget.conductorUser['id'] as int,
            conductorNombre: widget.conductorUser['nombre']?.toString() ?? 'Conductor',
            tipoVehiculo: widget.conductorUser['tipo_vehiculo']?.toString() ?? 'Sedan',
            solicitud: requests.first, // SOLO LA PRIMERA solicitud
          ),
        ),
      ).then((result) {
        // Cuando regresa de la pantalla de solicitud
        // SIEMPRE vuelve al home después de aceptar/rechazar
        if (mounted && _isOnline) {
          // Reiniciar búsqueda para encontrar la siguiente solicitud
          debugPrint('🔄 Reiniciando búsqueda de solicitudes...');
          _startSearchingRequests();
        }
      });
    } else {
      // No hay solicitudes, continuar buscando
      setState(() {
        _searchStatus = 'Buscando solicitudes cercanas...';
      });
    }
  }

  void _onSearchError(String error) {
    if (!mounted) return;
    
    debugPrint('❌ Error en búsqueda: $error');
    setState(() {
      _searchStatus = 'Error de conexión. Reintentando...';
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
      setState(() => _isOnline = true);
      _connectionController.forward();
      HapticFeedback.mediumImpact();
      
      // Limpiar caché de solicitudes procesadas (para permitir ver solicitudes que antes rechazó)
      TripRequestSearchService.clearProcessedRequests();
      
      // Iniciar búsqueda continua de solicitudes
      _startSearchingRequests();
      
      _showStatusSnackbar('¡Conectado! Buscando pasajeros...', AppColors.success);
    } else {
      // Desconectarse: Detener búsqueda
      setState(() => _isOnline = false);
      _connectionController.reverse();
      HapticFeedback.lightImpact();
      
      // Detener búsqueda de solicitudes
      _stopSearchingRequests();
      
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _connectionController.dispose();
    _positionStream?.cancel();
    _mapController.dispose();
    
    // Detener búsqueda si está activa
    _stopSearchingRequests();
    
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

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
                  color: Colors.black.withOpacity(0.1),
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
            'Viax Driver',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        // Botón de menú
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ),
      ],
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
        
        // Marcador de ubicación actual
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          
          // Panel inferior con controles
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
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
          
          // Divisor
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withOpacity(0.1),
          ),
          
          // Botón de conexión
          _buildConnectionButton(),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Estado actual
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? AppColors.success.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: _isOnline ? AppColors.success : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline ? 'En línea' : 'Desconectado',
                      style: TextStyle(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline
                          ? (_isSearchingRequests ? _searchStatus : 'Conectado')
                          : 'Conéctate para recibir viajes',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Indicador de batería o señal
              if (_isOnline)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Estadísticas rápidas
          Consumer<ConductorProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  _buildStatItem(
                    icon: Icons.access_time_rounded,
                    label: 'Hoy',
                    value: '0h',
                    color: AppColors.primary,
                  ),
                  _buildStatItem(
                    icon: Icons.directions_car_rounded,
                    label: 'Viajes',
                    value: '0',
                    color: AppColors.accent,
                  ),
                  _buildStatItem(
                    icon: Icons.payments_rounded,
                    label: 'Ganado',
                    value: '\$0',
                    color: AppColors.success,
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
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: color.withOpacity(0.9),
                    size: 22,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color?.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
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
          return Transform.scale(
            scale: _isOnline ? 1.0 : 0.98,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleOnlineStatus,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: _isOnline
                        ? LinearGradient(
                            colors: [
                              Colors.grey[300]!,
                              Colors.grey[400]!,
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_isOnline
                                ? Colors.grey[400]!
                                : AppColors.primary)
                            .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isOnline
                            ? Icons.power_settings_new_rounded
                            : Icons.flash_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isOnline ? 'Desconectar' : 'Conectarse',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

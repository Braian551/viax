import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/auth/google_auth_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/user/presentation/widgets/location_input.dart';
import 'package:viax/src/global/services/mapbox_service.dart';
import 'package:viax/src/features/user/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:viax/src/global/services/active_trip_navigation_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/features/user/presentation/screens/user_profile_screen.dart';
import 'package:viax/src/features/user/presentation/screens/trip_history_screen.dart';
import 'package:viax/src/features/notifications/notifications.dart';
import 'package:viax/src/features/user/presentation/widgets/home/map_loading_shimmer.dart';
import 'package:viax/src/global/widgets/active_trip_alert.dart';
import 'package:viax/src/features/user/services/user_trips_service.dart';

class HomeUserScreen extends StatefulWidget {
  const HomeUserScreen({super.key});

  @override
  State<HomeUserScreen> createState() => _HomeUserScreenState();
}

class _HomeUserScreenState extends State<HomeUserScreen> with TickerProviderStateMixin {
  // Mapa y Ubicación
  final MapController _mapController = MapController();
  geo.Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isMapReady = false;
  bool _hasMapLoadError = false;
  bool _isRetryingMap = false;
  int _tileLoadErrors = 0;
  Timer? _mapLoadTimeout;
  Key _mapWidgetKey = UniqueKey();

  // Usuario
  String? _userName;
  int? _userId;
  bool _loadingUser = true;

  // Notificaciones
  int _unreadNotifications = 0;
  Timer? _notificationTimer;

  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Navegación
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserData();
    _requestLocationPermission();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
  }

  Future<void> _requestLocationPermission() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always) {
        _getCurrentLocation();
      } else {
        setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      debugPrint('Error location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          _hasMapLoadError = false;
        });
        _startMapLoadWatchdog();
        _centerMapOnLocation(position);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _startMapLoadWatchdog() {
    _mapLoadTimeout?.cancel();
    _isMapReady = false;
    _mapLoadTimeout = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (!_isMapReady) {
        setState(() {
          _hasMapLoadError = true;
        });
      }
    });
  }

  void _handleMapTileError(Object error, [StackTrace? stackTrace]) {
    debugPrint('Map tile error: $error');
    if (!mounted || _hasMapLoadError) return;

    _tileLoadErrors++;
    if (_tileLoadErrors >= 3) {
      setState(() {
        _hasMapLoadError = true;
      });
    }
  }

  Future<void> _retryMapLoad() async {
    if (_isRetryingMap) return;

    setState(() {
      _isRetryingMap = true;
      _hasMapLoadError = false;
      _tileLoadErrors = 0;
      _isMapReady = false;
      _mapWidgetKey = UniqueKey();
    });

    if (_currentPosition == null) {
      await _requestLocationPermission();
    } else {
      _startMapLoadWatchdog();
      _centerMapOnLocation(_currentPosition!);
    }

    if (!mounted) return;
    setState(() {
      _isRetryingMap = false;
    });
  }

  void _centerMapOnLocation(geo.Position position) {
    try {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16.0,
      );
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final sess = await UserService.getSavedSession();
      if (sess != null) {
        final id = sess['id'] as int?;
        final email = sess['email'] as String?;
        
        // Verificar si el usuario necesita ingresar teléfono
        final requiresPhone = await GoogleAuthService.checkRequiresPhone();
        if (requiresPhone && mounted) {
          Navigator.of(context).pushReplacementNamed(
            RouteNames.phoneRequired,
            arguments: sess,
          );
          return;
        }
        
        final profile = await UserService.getProfile(userId: id, email: email);
        if (profile != null && profile['success'] == true) {
          final user = profile['user'];
          
          // Doble verificación del teléfono desde el servidor
          final telefono = user?['telefono'];
          if ((telefono == null || telefono.toString().isEmpty) && mounted) {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.phoneRequired,
              arguments: user,
            );
            return;
          }
          
          if (mounted) {
            setState(() {
              _userName = user?['nombre'] ?? 'Usuario';
              _userId = user?['id'] as int?;
              _loadingUser = false;
            });
            _animationController.forward();
            
            // Cargar notificaciones después de obtener el usuario
            if (_userId != null) {
              _loadUnreadNotifications();
              _startNotificationPolling();
            }
          }
        }
      }
    } catch (_) {}
    
    if (_loadingUser && mounted) {
      setState(() => _loadingUser = false);
      _animationController.forward();
    }
  }

  /// Carga el conteo de notificaciones no leídas
  Future<void> _loadUnreadNotifications() async {
    if (_userId == null) return;
    final count = await NotificationService.getUnreadCount(userId: _userId!);
    if (mounted) {
      setState(() => _unreadNotifications = count);
    }
  }

  /// Inicia el polling para actualizar notificaciones
  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUnreadNotifications(),
    );
  }

  /// Abre la pantalla de notificaciones
  void _openNotifications() {
    if (_userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(userId: _userId!),
      ),
    ).then((_) {
      // Recargar conteo al volver
      _loadUnreadNotifications();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController.dispose();
    _notificationTimer?.cancel();
    _mapLoadTimeout?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      extendBody: true, // Para que el bottom nav flote sobre el mapa
      appBar: _buildAppBar(isDark),
      body: Stack(
        children: [
          // 1. Mapa de fondo
          _buildMap(isDark),

          // 2. Contenido Principal (Search Box, etc)
          if (_selectedIndex == 0)
            _buildHomeOverlay(isDark),

          // 3. Otras Pestañas (Historial, Perfil, etc)
          if (_selectedIndex != 0)
            _buildTabContent(isDark),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onIndexChanged: (index) => setState(() => _selectedIndex = index),
        isDark: isDark,
        items: [
          CustomNavBarItem(icon: Icons.home_rounded, label: 'Inicio'),
          CustomNavBarItem(icon: Icons.history_rounded, label: 'Viajes'),
          CustomNavBarItem(icon: Icons.person_rounded, label: 'Perfil'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(110),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                // Contenedor principal con efecto glass (más ancho)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: (isDark 
                            ? Colors.white.withValues(alpha: 0.1) 
                            : Colors.white.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: (isDark 
                              ? Colors.white.withValues(alpha: 0.2) 
                              : Colors.white.withValues(alpha: 0.4)),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Logo
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDark 
                                  ? Colors.white.withValues(alpha: 0.15) 
                                  : Colors.white.withValues(alpha: 0.4)),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 32,
                                height: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Saludo
                            if (!_loadingUser)
                              Expanded(
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Hola,',
                                          style: TextStyle(
                                            color: isDark ? Colors.white70 : Colors.black54,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _userName ?? 'Usuario',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : Colors.black87,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                const SizedBox(width: 12),
                // Botón de Notificaciones con badge
                NotificationBadge(
                  count: _unreadNotifications,
                  isDark: isDark,
                  onTap: _openNotifications,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    if (_isLoadingLocation) {
      return const MapLoadingShimmer();
    }

    if (_hasMapLoadError) {
      return _buildMapErrorFallback(isDark);
    }

    if (_currentPosition == null) {
      return Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: Center(
          child: Text(
            'Ubicación no disponible',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      );
    }

    return FlutterMap(
      key: _mapWidgetKey,
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        initialZoom: 16.0,
        minZoom: 3.0,
        maxZoom: 18.0,
        onMapReady: () {
          if (!mounted) return;
          _mapLoadTimeout?.cancel();
          setState(() {
            _isMapReady = true;
            _tileLoadErrors = 0;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
          errorTileCallback: (tile, error, stackTrace) {
            _handleMapTileError(error, stackTrace);
          },
        ),
        // Marcador de usuario (Halo effect)
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halo animado (simulado estático por ahora)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapErrorFallback(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 44,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el mapa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puede ser un fallo temporal del SDK o de la conexión.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _isRetryingMap ? null : _retryMapLoad,
              icon: _isRetryingMap
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(_isRetryingMap ? 'Reintentando...' : 'Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildHomeOverlay(bool isDark) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 110, // Posición fija para asegurar que esté abajo
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (isDark 
                    ? Colors.black.withValues(alpha: 0.4) 
                    : Colors.white.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (isDark 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.white.withValues(alpha: 0.4)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¿A dónde vas?',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Input simulado
                    Hero(
                      tag: 'search_destination_box',
                      child: Material(
                        color: Colors.transparent,
                        child: LocationInput(
                          icon: Icons.search_rounded,
                          iconColor: AppColors.primary,
                          label: 'Destino',
                          value: null,
                          placeholder: 'Buscar destino',
                          isDark: isDark,
                          isDestination: true,
                          onTap: () async {
                            // Verificar viaje activo
                            // 1. Verificación local (más rápida y fiable si la app sigue vivía)
                            if (ActiveTripNavigationService().hasActiveTrip) {
                               showActiveTripAlert(context, isConductor: false, userId: _userId);
                               return;
                            }

                            // 2. Verificación remota
                            if (_userId != null) {
                              try {
                                final result = await UserTripsService.getHistorial(userId: _userId!, limit: 5);
                                if (result['success'] == true) {
                                  final trips = result['viajes'] as List<UserTripModel>;
                                  // Un viaje se considera activo si no está completado ni cancelado
                                  final hasActive = trips.any((t) => !t.isCompletado && !t.isCancelado);
                                  
                                  if (hasActive) {
                                    if (!mounted) return;
                                    showActiveTripAlert(context, isConductor: false, userId: _userId);
                                    return;
                                  }
                                }
                              } catch (_) {}
                            }

                            // Animación: ocultar el overlay para que no se vean duplicados
                            await _animationController.reverse();
                            await Navigator.pushNamed(
                              context,
                              RouteNames.requestTrip,
                              arguments: {
                                'selecting': 'destination',
                                'currentPosition': _currentPosition,
                              },
                            );
                            // Restaurar overlay al volver
                            if (mounted) _animationController.forward();
                          },
                          onClear: null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Accesos rápidos (Casa, Trabajo)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Quick actions replaced by QuickAction widget (widgets/quick_action.dart)



  Widget _buildTabContent(bool isDark) {
    // Perfil
    if (_selectedIndex == 2) {
      return const UserProfileScreen();
    }
    
    // Historial de Viajes
    if (_selectedIndex == 1) {
      if (_userId == null) {
        return Container(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return TripHistoryScreen(userId: _userId!);
    }
    
    // No debería llegar aquí
    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
    );
  }


}

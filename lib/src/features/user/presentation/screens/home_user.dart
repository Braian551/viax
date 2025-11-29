import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/mapbox_service.dart';
import 'package:viax/src/features/user/presentation/widgets/custom_bottom_nav_bar.dart';

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

  // Usuario
  String? _userName;
  bool _loadingUser = true;

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
    
    // Marcar mapa como listo
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isMapReady = true);
      }
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
        });
        _centerMapOnLocation(position);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
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
        final profile = await UserService.getProfile(userId: id, email: email);
        if (profile != null && profile['success'] == true) {
          final user = profile['user'];
          if (mounted) {
            setState(() {
              _userName = user?['nombre'] ?? 'Usuario';
              _loadingUser = false;
            });
            _animationController.forward();
          }
        }
      }
    } catch (_) {}
    
    if (_loadingUser && mounted) {
      setState(() => _loadingUser = false);
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController.dispose();
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
          CustomNavBarItem(icon: Icons.payment_rounded, label: 'Pagos'),
          CustomNavBarItem(icon: Icons.person_rounded, label: 'Perfil'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      title: Row(
        children: [
          // Logo con efecto Glass
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkCard : Colors.white).withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 12),
          // Saludo
          if (!_loadingUser)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola,',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _userName ?? 'Usuario',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        // Botón de Notificaciones
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkCard : Colors.white).withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildMap(bool isDark) {
    if (_isLoadingLocation) {
      return Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
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
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
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
                      color: AppColors.primary.withOpacity(0.2),
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
                          color: AppColors.primary.withOpacity(0.5),
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

  Widget _buildHomeOverlay(bool isDark) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 110, // Posición fija para asegurar que esté abajo
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkCard : Colors.white).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                    GestureDetector(
                      onTap: () {
                        // TODO: Navegar a búsqueda
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.06),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: isDark ? Colors.white70 : AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Buscar destino',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Accesos rápidos (Casa, Trabajo)
                    Row(
                      children: [
                        _buildQuickAction(
                          icon: Icons.home_rounded,
                          label: 'Casa',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 16),
                        _buildQuickAction(
                          icon: Icons.work_rounded,
                          label: 'Trabajo',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.blue.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    // Fondo sólido para otras pestañas
    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        child: Center(
          child: Text(
            'Contenido de pestaña $_selectedIndex',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }


}

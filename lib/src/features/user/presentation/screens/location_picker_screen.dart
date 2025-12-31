import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
// Removed http import
import 'package:geolocator/geolocator.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';
import '../../../../global/services/mapbox_service.dart';

/// Pantalla mejorada de selección de ubicación en mapa
/// Con animaciones suaves, efecto glass y diseño moderno estilo DiDi/Uber
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final String title;
  final Color accentColor;

  const LocationPickerScreen({
    super.key,
    this.initialPosition,
    this.title = 'Seleccionar ubicación',
    this.accentColor = const Color(0xFF2196F3), // AppColors.primary
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(6.2442, -75.5812); // Default to Medellin
  LatLng? _userLocation;
  String _address = 'Cargando dirección...';
  bool _isLoadingAddress = false;
  bool _isMoving = false;
  bool _isMapReady = false;

  Timer? _debounce;

  // Animaciones
  late AnimationController _pinAnimationController;
  late Animation<double> _pinBounceAnimation;
  late Animation<double> _pinShadowAnimation;

  late AnimationController _panelAnimationController;
  late Animation<Offset> _panelSlideAnimation;
  late Animation<double> _panelFadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    if (widget.initialPosition != null) {
      _currentCenter = widget.initialPosition!;
      _getAddress(_currentCenter);
    } else {
      _getCurrentLocation();
    }
  }

  void _setupAnimations() {
    // Animación del pin cuando se mueve el mapa
    _pinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pinBounceAnimation = Tween<double>(begin: 0, end: -25).animate(
      CurvedAnimation(
        parent: _pinAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pinShadowAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _pinAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Animación del panel inferior
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _panelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _panelFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _panelAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Animación de pulso para ubicación del usuario
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    // Iniciar animación del panel
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _panelAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _pinAnimationController.dispose();
    _panelAnimationController.dispose();
    _pulseController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentCenter = latLng;
          _userLocation = latLng;
        });

        if (_isMapReady) {
          _mapController.move(latLng, 16);
        }

        _getAddress(latLng);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _getAddress(LatLng point) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      setState(() => _isLoadingAddress = true);

      try {
        final place = await MapboxService.reverseGeocode(
          position: point,
        );

        if (place != null && mounted) {
          setState(() {
            _address = place.placeName;
          });
        }
      } catch (e) {
        debugPrint('Error fetching address: $e');
        if (mounted) {
          setState(() => _address = 'Error obteniendo dirección');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingAddress = false);
        }
      }
    });
  }

  void _centerOnUserLocation() {
    if (_userLocation == null) {
      _getCurrentLocation();
      return;
    }

    HapticFeedback.mediumImpact();
    _mapController.move(_userLocation!, 16);
    _getAddress(_userLocation!);
  }

  void _confirmLocation() {
    HapticFeedback.mediumImpact();

    final location = SimpleLocation(
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      address: _address,
    );

    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Stack(
        children: [
          // Mapa
          _buildMap(isDark),

          // Pin central animado
          _buildCenterPin(),

          // Botón de volver
          _buildBackButton(isDark),

          // Botón de mi ubicación
          _buildMyLocationButton(isDark),

          // Panel inferior con dirección
          _buildBottomPanel(isDark, bottomPadding),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentCenter,
        initialZoom: 15.0,
        onMapReady: () {
          setState(() => _isMapReady = true);
          if (widget.initialPosition == null && _userLocation != null) {
            _mapController.move(_userLocation!, 16);
          }
        },
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && _isMapReady) {
            if (!_isMoving) {
              _pinAnimationController.forward();
            }
            setState(() {
              _isMoving = true;
              _currentCenter = position.center;
            });
          }
        },
        onMapEvent: (event) {
          if (event is MapEventMoveEnd && _isMapReady) {
            _pinAnimationController.reverse();
            setState(() => _isMoving = false);
            _getAddress(_currentCenter);
          }
        },
        interactionOptions: const InteractionOptions(
          enableMultiFingerGestureRace: true,
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
              : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.viax',
        ),
        // Marcador de ubicación del usuario
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 60,
                height: 60,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulso exterior
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                alpha: 0.3 * (1.5 - _pulseAnimation.value),
                              ),
                            ),
                          ),
                        ),
                        // Punto central
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
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

  Widget _buildCenterPin() {
    return Center(
      child: AnimatedBuilder(
        animation: _pinAnimationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _pinBounceAnimation.value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pin principal
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                // Flecha
                CustomPaint(
                  size: const Size(20, 12),
                  painter: _TrianglePainter(color: widget.accentColor),
                ),
                const SizedBox(height: 4),
                // Sombra del pin
                Transform.scale(
                  scale: _pinShadowAnimation.value,
                  child: Container(
                    width: 12,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Offset para centrar visualmente
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyLocationButton(bool isDark) {
    return Positioned(
      right: 16,
      bottom: 200,
      child: GestureDetector(
        onTap: _centerOnUserLocation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.my_location_rounded,
                color: widget.accentColor,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark, double bottomPadding) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _panelSlideAnimation,
        child: FadeTransition(
          opacity: _panelFadeAnimation,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
                decoration: BoxDecoration(
                  color: isDark
                    ? Colors.grey[900]!.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Título
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Ubicación seleccionada
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: widget.accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ubicación seleccionada',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isMoving || _isLoadingAddress
                                    ? Row(
                                        children: [
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                widget.accentColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isMoving ? 'Moviendo...' : 'Buscando...',
                                            key: const ValueKey('loading'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        _address,
                                        key: ValueKey(_address),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.grey[900],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Botón de confirmar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isMoving || _isLoadingAddress
                            ? null
                            : _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accentColor,
                            disabledBackgroundColor:
                              widget.accentColor.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirmar ubicación',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
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
      ),
    );
  }
}

/// Painter para el triángulo del pin
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

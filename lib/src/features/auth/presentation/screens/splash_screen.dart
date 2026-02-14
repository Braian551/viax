import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/auth/presentation/widgets/logo_transition.dart';
import 'package:viax/src/global/services/trip_persistence_service.dart';
import 'package:viax/src/features/user/services/trip_request_service.dart';
import 'package:viax/src/features/user/presentation/screens/user_active_trip_screen.dart';
import 'package:viax/src/features/user/presentation/screens/user_trip_accepted_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/active_trip_screen.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

/// Indicador de carga minimalista inspirado en TikTok
class MinimalLoadingIndicator extends StatefulWidget {
  const MinimalLoadingIndicator({super.key});

  @override
  State<MinimalLoadingIndicator> createState() => _MinimalLoadingIndicatorState();
}

class _MinimalLoadingIndicatorState extends State<MinimalLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 60,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnim.value,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: _opacityAnim.value * (isDark ? 1.0 : 0.7)),
                borderRadius: BorderRadius.circular(1),
                boxShadow: isDark ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3 * _opacityAnim.value),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _slideAnim; // Ahora es opacidad del título
  late final Animation<double> _subtitleSlideAnim; // Ahora es opacidad del subtítulo
  late final Animation<double> _textScaleAnim;
  late final Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();

    // Animación principal
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Animación de pulso continuo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Animación de rotación sutil
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Escala con efecto bounce
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Fade in suave
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Fade in para el texto principal
    _slideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
      ),
    );

    // Fade in para el subtítulo (retrasado)
    _subtitleSlideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeIn),
      ),
    );

    // Efecto de escala para el texto (efecto pop natural)
    _textScaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.elasticOut),
      ),
    );

    // Pulso del glow
    _pulseAnim = Tween<double>(begin: 0.15, end: 0.30).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Rotación sutil
    _rotationAnim = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
    _rotationController.forward();

    // Delay navigation to ensure animation is visible
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    // --- LOGICA DE RECUPERACIÓN DE VIAJE ---
    try {
      Map<String, dynamic>? tripToRecover;
      Map<String, dynamic>? conductorInfo;
      String? userRole;

      // 1. Intentar recuperación local
      final savedTrip = await TripPersistenceService().getActiveTrip();
      
      if (savedTrip != null) {
        debugPrint('♻️ Intentando recuperar viaje local ${savedTrip.tripId}...');
        userRole = savedTrip.userRole;
        final tripStatus = await TripRequestService.getTripStatus(
          solicitudId: savedTrip.tripId,
        );
        if (tripStatus['success'] == true) {
          tripToRecover = tripStatus['trip'];
          // El conductor viene dentro de trip, no en la raíz
          conductorInfo = tripStatus['trip']?['conductor'] as Map<String, dynamic>?;
        }
      } 
      // 2. Si no hay local, consultar backend (Fallback)
      else {
        final session = await UserService.getSavedSession();
        if (session != null) {
          final userId = session['id'];
          final role = session['tipo_usuario'];
          userRole = role;
          
          if (userId != null) {
            final activeCheck = await TripRequestService.checkActiveTrip(
              userId: userId,
              role: role,
            );
            
            if (activeCheck['success'] == true) {
               debugPrint('🌐 Viaje activo encontrado en backend: ${activeCheck['trip']['id']}');
               tripToRecover = activeCheck['trip'];
               // El conductor viene dentro de trip, no en la raíz
               conductorInfo = activeCheck['trip']?['conductor'] as Map<String, dynamic>?;
            }
          }
        }
      }

      // 3. Procesar redirección si se encontró un viaje
      if (tripToRecover != null && userRole != null) {
         final trip = tripToRecover;
         final estado = trip['estado'];
          if (estado == 'en_curso' || estado == 'conductor_llego' || estado == 'recogido' || estado == 'aceptada' || estado == 'en_camino') {
            debugPrint('✅ Viaje activo validado ($estado). Redirigiendo como $userRole...');
            
            if (mounted) {
              if (userRole == 'conductor') {
                 // Recuperar datos para conductor
              int conductorId = int.tryParse(trip['conductor_id']?.toString() ?? '') ?? 0;
                 
                 // Fallback: Si no viene el ID del conductor en el viaje, usar el de la sesión
                 if (conductorId == 0) {
                    final session = await UserService.getSavedSession();
                if (!mounted) return;
                    if (session != null && session['tipo_usuario'] == 'conductor') {
                       conductorId = session['id'];
                    }
                 }

                 Navigator.of(context).pushReplacement(
                   MaterialPageRoute(
                     builder: (context) => ConductorActiveTripScreen(
                       conductorId: conductorId,
                       solicitudId: int.tryParse(trip['id']?.toString() ?? '') ?? 0,
                       clienteId: int.tryParse(trip['cliente_id']?.toString() ?? '') ?? 0,
                       origenLat: double.tryParse(trip['origen']?['latitud']?.toString() ?? '') ?? 0.0,
                       origenLng: double.tryParse(trip['origen']?['longitud']?.toString() ?? '') ?? 0.0,
                       direccionOrigen: trip['origen']?['direccion']?.toString() ?? '',
                       destinoLat: double.tryParse(trip['destino']?['latitud']?.toString() ?? '') ?? 0.0,
                       destinoLng: double.tryParse(trip['destino']?['longitud']?.toString() ?? '') ?? 0.0,
                       direccionDestino: trip['destino']?['direccion']?.toString() ?? '',
                       initialTripStatus: trip['estado'],
                     ),
                   ),
                 );
                 return;
              } else {
                // Recuperar datos para cliente
                final tripId = int.tryParse(trip['id']?.toString() ?? '') ?? 0;
                final clienteId = int.tryParse(trip['cliente_id']?.toString() ?? '') ?? 0;
                final origenLat = double.tryParse(trip['origen']?['latitud']?.toString() ?? '') ?? 0.0;
                final origenLng = double.tryParse(trip['origen']?['longitud']?.toString() ?? '') ?? 0.0;
                final direccionOrigen = trip['origen']?['direccion']?.toString() ?? '';
                final destinoLat = double.tryParse(trip['destino']?['latitud']?.toString() ?? '') ?? 0.0;
                final destinoLng = double.tryParse(trip['destino']?['longitud']?.toString() ?? '') ?? 0.0;
                final direccionDestino = trip['destino']?['direccion']?.toString() ?? '';

                final shouldGoToMeetingPoint =
                    estado == 'aceptada' ||
                    estado == 'conductor_asignado' ||
                    estado == 'en_camino' ||
                    estado == 'conductor_llego';

                if (shouldGoToMeetingPoint) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => UserTripAcceptedScreen(
                        solicitudId: tripId,
                        clienteId: clienteId,
                        latitudOrigen: origenLat,
                        longitudOrigen: origenLng,
                        direccionOrigen: direccionOrigen,
                        latitudDestino: destinoLat,
                        longitudDestino: destinoLng,
                        direccionDestino: direccionDestino,
                        conductorInfo: conductorInfo,
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => UserActiveTripScreen(
                        solicitudId: tripId,
                        clienteId: clienteId,
                        origenLat: origenLat,
                        origenLng: origenLng,
                        direccionOrigen: direccionOrigen,
                        destinoLat: destinoLat,
                        destinoLng: destinoLng,
                        direccionDestino: direccionDestino,
                        conductorInfo: conductorInfo,
                      ),
                    ),
                  );
                }
                 return;
              }
            }
          } else {
             // Viaje completado/cancelado
             await TripPersistenceService().clearActiveTrip();
          }
      }
    } catch (e) {
      debugPrint('⚠️ Error en recuperación de viaje: $e');
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(RouteNames.authWrapper);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _pulseController, _rotationController]),
        builder: (context, child) {
          return Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing circular logo con animaciones - HERO ANIMATION
                  LogoHeroTransition(
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Transform.rotate(
                        angle: _rotationAnim.value,
                        child: AnimatedLogo(
                          size: 86,
                          glowOpacity: Theme.of(context).brightness == Brightness.dark 
                              ? _pulseAnim.value * 0.4
                              : _pulseAnim.value * 0.3,
                          scale: 1.0,
                          rotation: 0.0,
                          showGlow: true,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // App name con animación de escala y fade in
                  Transform.translate(
                    offset: const Offset(0, -15),
                    child: Transform.scale(
                    scale: _textScaleAnim.value,
                    child: Opacity(
                      opacity: _slideAnim.value,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Viax',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryLight,
                                      AppColors.accent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ).createShader(const Rect.fromLTWH(0, 0, 200, 0)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),

                  const SizedBox(height: 0),

                  // Subtítulo con fade in independiente
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Opacity(
                    opacity: _subtitleSlideAnim.value,
                    child: Text(
                      'Viaja fácil, llega rápido',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

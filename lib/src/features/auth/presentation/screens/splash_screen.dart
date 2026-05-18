import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/auth/presentation/widgets/logo_transition.dart';
import 'package:viax/src/global/services/trip_persistence_service.dart';
import 'package:viax/src/features/user/services/trip_request_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/trip_status_navigation_service.dart';
import 'package:viax/src/global/widgets/trip_completion/trip_completion_widgets.dart';
import 'package:viax/src/global/services/rating_service.dart';

/// Indicador de carga minimalista inspirado en TikTok
class MinimalLoadingIndicator extends StatefulWidget {
  const MinimalLoadingIndicator({super.key});

  @override
  State<MinimalLoadingIndicator> createState() =>
      _MinimalLoadingIndicatorState();
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

    _progressAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
                color: AppColors.primary.withValues(
                  alpha: _opacityAnim.value * (isDark ? 1.0 : 0.7),
                ),
                borderRadius: BorderRadius.circular(1),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.3 * _opacityAnim.value,
                          ),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StartupRouteDecision {
  final String routeName;
  final Object? arguments;

  const _StartupRouteDecision(this.routeName, {this.arguments});
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const String _startupSplashSeenKey = 'startup_splash_seen_v1';

  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _slideAnim; // Ahora es opacidad del título
  late final Animation<double>
  _subtitleSlideAnim; // Ahora es opacidad del subtítulo
  late final Animation<double> _textScaleAnim;
  late final Animation<double> _rotationAnim;
  bool? _showAnimatedSplash;

  bool get _isCurrentRoute => ModalRoute.of(context)?.isCurrent ?? true;

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
    );

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
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotación sutil
    _rotationAnim = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    _configureStartupFlow();
  }

  Future<_StartupRouteDecision> _resolveStartupRouteDecision() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    if (!onboardingCompleted) {
      return const _StartupRouteDecision(RouteNames.onboarding);
    }

    final session = await UserService.getActiveSession();
    if (session == null) {
      return const _StartupRouteDecision(RouteNames.welcome);
    }

    final tipoUsuario = UserService.normalizeUserRole(session['tipo_usuario']);
    if (tipoUsuario == 'soporte_tecnico') {
      return _StartupRouteDecision(
        RouteNames.supportHome,
        arguments: {'support_user': session},
      );
    }

    if (tipoUsuario == 'administrador' || tipoUsuario == 'admin') {
      return _StartupRouteDecision(
        RouteNames.adminHome,
        arguments: {'admin_user': session},
      );
    }

    if (tipoUsuario == 'conductor') {
      return _StartupRouteDecision(
        RouteNames.conductorHome,
        arguments: {'conductor_user': session},
      );
    }

    if (tipoUsuario == 'empresa') {
      return _StartupRouteDecision(
        RouteNames.companyHome,
        arguments: {'user': session},
      );
    }

    if (tipoUsuario == null) {
      return const _StartupRouteDecision(RouteNames.authWrapper);
    }

    return _StartupRouteDecision(
      RouteNames.home,
      arguments: {'email': session['email'], 'user': session},
    );
  }

  bool _canUseImmediateStartupRoute(_StartupRouteDecision decision) {
    return decision.routeName == RouteNames.home ||
        decision.routeName == RouteNames.welcome ||
        decision.routeName == RouteNames.onboarding;
  }

  void _navigateToStartupDecision(_StartupRouteDecision decision) {
    if (!mounted || !_isCurrentRoute) return;

    Navigator.of(
      context,
    ).pushReplacementNamed(decision.routeName, arguments: decision.arguments);
  }

  Future<void> _configureStartupFlow() async {
    final prefs = await SharedPreferences.getInstance();
    final startupSplashSeen = prefs.getBool(_startupSplashSeenKey) ?? false;

    if (!mounted) return;

    if (startupSplashSeen) {
      setState(() => _showAnimatedSplash = false);
      _controller.value = 1.0;
      _rotationController.value = 0.0;
      await _navigateAfterDelay(skipAnimationDelay: true);
      return;
    }

    await prefs.setBool(_startupSplashSeenKey, true);

    if (!mounted) return;

    setState(() => _showAnimatedSplash = true);
    _pulseController.repeat(reverse: true);
    _controller.forward();
    _rotationController.forward();
    await _navigateAfterDelay(skipAnimationDelay: false);
  }

  Future<void> _navigateAfterDelay({required bool skipAnimationDelay}) async {
    final recoveryStartedAt = DateTime.now();
    debugPrint(
      '[TripRecovery] ts=${recoveryStartedAt.toIso8601String()} tripId=0 latency_ms=0 result=start',
    );

    // Esperar la animación completa solo en el primer arranque.
    if (!skipAnimationDelay) {
      await Future.delayed(const Duration(milliseconds: 3000));
    }

    if (!mounted) return;
    if (!_isCurrentRoute) return;

    if (skipAnimationDelay) {
      final startupDecision = await _resolveStartupRouteDecision();
      final savedTrip = await TripPersistenceService().getActiveTrip();

      if (!mounted || !_isCurrentRoute) return;

      if (savedTrip == null && _canUseImmediateStartupRoute(startupDecision)) {
        _navigateToStartupDecision(startupDecision);
        return;
      }
    }

    // 1. Obtener sesión actual (para fallback de IDs)
    final session = await UserService.getActiveSession();
    int? sessionUserId;
    String? sessionUserRole;

    if (session != null) {
      sessionUserId = session['id'];
      sessionUserRole = UserService.normalizeUserRole(session['tipo_usuario']);
    }

    Map<String, dynamic>? tripToRecover;
    Map<String, dynamic>? conductorInfo;
    String? userRole;

    // 2. Intentar recuperación local
    try {
      final savedTrip = await TripPersistenceService().getActiveTrip();

      if (savedTrip != null && sessionUserId != null && sessionUserRole != null) {
        debugPrint(
          '♻️ Intentando recuperar viaje local ${savedTrip.tripId}...',
        );
        userRole = savedTrip.userRole;
        final tripStatus = await TripRequestService.getTripStatus(
          solicitudId: savedTrip.tripId,
          waitSeconds: 2,
        );
        if (tripStatus['success'] == true) {
          tripToRecover = tripStatus['trip'];
          // El conductor viene dentro de trip, no en la raíz
          conductorInfo =
              tripStatus['trip']?['conductor'] as Map<String, dynamic>?;
        }
      }
      // 3. Si no hay local, consultar backend como respaldo
      else if (sessionUserId != null && sessionUserRole != null) {
        userRole = sessionUserRole;

        final activeCheck = await TripRequestService.checkActiveTrip(
          userId: sessionUserId,
          role: sessionUserRole,
        );

        final dynamic maybeTrip =
            activeCheck['trip'] ??
            (activeCheck['data'] as Map<String, dynamic>?)?['trip'] ??
            activeCheck['trip_data'];

        if (activeCheck['success'] == true && maybeTrip is Map) {
          final tripMap = Map<String, dynamic>.from(maybeTrip);
          debugPrint(
            '🌐 Viaje activo encontrado en backend: ${tripMap['id'] ?? 'sin_id'}',
          );
          tripToRecover = tripMap;

          final dynamic maybeConductor = tripMap['conductor'];
          conductorInfo = maybeConductor is Map
              ? Map<String, dynamic>.from(maybeConductor)
              : null;
        }
      }

      // 4. Procesar la redirección si se encontró un viaje
      if (tripToRecover != null && userRole != null) {
        final trip = Map<String, dynamic>.from(tripToRecover);
        final recoveredTripId = int.tryParse(trip['id']?.toString() ?? '') ?? 0;
        debugPrint(
          '[TripRecovery] ts=${DateTime.now().toIso8601String()} tripId=$recoveredTripId '
          'latency_ms=${DateTime.now().difference(recoveryStartedAt).inMilliseconds} result=trip_found',
        );
        final status = TripStatusNavigationService.normalizeStatus(
          trip['estado'],
        );

        if (TripStatusNavigationService.isCompletedStatus(status)) {
          final showSummary =
              TripStatusNavigationService.shouldShowPendingSummary(
                trip: trip,
                isConductor: userRole == 'conductor',
              );

          if (showSummary && mounted && _isCurrentRoute) {
            // Evita bucle de resumen al reabrir app: limpiar persistencia antes de navegar.
            await TripPersistenceService().clearActiveTrip();

            if (!mounted || !_isCurrentRoute) return;

            final solicitudId = int.tryParse(trip['id']?.toString() ?? '') ?? 0;
            final origen =
                (trip['origen']?['direccion'] ??
                        trip['direccion_recogida'] ??
                        trip['direccion_origen'] ??
                        'Origen')
                    .toString();
            final destino =
                (trip['destino']?['direccion'] ??
                        trip['direccion_destino'] ??
                        'Destino')
                    .toString();
            final distanciaKm = _toDouble(
              trip['distancia_km'] ??
                  trip['distancia_recorrida'] ??
                  trip['distancia_estimada'],
            );
            final duracionSeg = _toInt(
              trip['duracion_segundos'] ??
                  trip['tiempo_transcurrido_seg'] ??
                  (trip['duracion_minutos'] ?? trip['tiempo_transcurrido']),
            );
            final precio = _toDouble(
              trip['precio_final'] ?? trip['precio_estimado'] ?? 0,
            );

            final miUsuarioId =
                sessionUserId ??
                _toInt(
                  userRole == 'conductor'
                      ? trip['conductor_id']
                      : trip['cliente_id'],
                );
            final otroUsuarioId = _toInt(
              userRole == 'conductor'
                  ? trip['cliente_id']
                  : trip['conductor_id'],
            );

            final otroNombre = userRole == 'conductor'
                ? (trip['cliente_nombre']?.toString() ?? 'Pasajero')
                : ((conductorInfo?['nombre']?.toString() ??
                          trip['conductor']?['nombre']?.toString()) ??
                      'Conductor');
            final otroFoto = userRole == 'conductor'
                ? trip['cliente_foto']?.toString()
                : (conductorInfo?['foto']?.toString() ??
                      trip['conductor']?['foto']?.toString());
            final otroCalificacion = _toNullableDouble(
              userRole == 'conductor'
                  ? (trip['cliente_calificacion'] ?? trip['cliente_rating'])
                  : (conductorInfo?['calificacion'] ??
                        trip['conductor']?['calificacion']),
            );

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => TripCompletionScreen(
                  userType: userRole == 'conductor'
                      ? TripCompletionUserType.conductor
                      : TripCompletionUserType.cliente,
                  tripData: TripCompletionData(
                    solicitudId: solicitudId,
                    origen: origen,
                    destino: destino,
                    distanciaKm: distanciaKm,
                    duracionSegundos: duracionSeg,
                    precio: precio,
                    metodoPago: 'Efectivo',
                    otroUsuarioNombre: otroNombre,
                    otroUsuarioFoto: otroFoto,
                    otroUsuarioCalificacion: otroCalificacion,
                  ),
                  miUsuarioId: miUsuarioId,
                  otroUsuarioId: otroUsuarioId,
                  onSubmitRating: (rating, comentario) async {
                    if (miUsuarioId == 0 || otroUsuarioId == 0) {
                      return {
                        'success': false,
                        'message': 'No se pudo identificar a los participantes',
                      };
                    }
                    return RatingService.enviarCalificacion(
                      solicitudId: solicitudId,
                      calificadorId: miUsuarioId,
                      calificadoId: otroUsuarioId,
                      calificacion: rating,
                      tipoCalificador: userRole == 'conductor'
                          ? 'conductor'
                          : 'cliente',
                      comentario: comentario,
                    );
                  },
                  onComplete: () {
                    // Refuerzo defensivo por si el flujo vuelve al splash.
                    TripPersistenceService().clearActiveTrip();
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                ),
              ),
            );
            return;
          }

          await TripPersistenceService().clearActiveTrip();
        } else {
          TripNavigationDecision? decision;
          if (userRole == 'conductor') {
            decision = TripStatusNavigationService.resolveConductorNavigation(
              trip: trip,
              fallbackConductorId: sessionUserId ?? 0,
            );
          } else {
            decision = TripStatusNavigationService.resolveUserNavigation(
              trip: trip,
              fallbackClienteId: sessionUserId ?? 0,
            );
          }

          if (decision != null && mounted && _isCurrentRoute) {
            Navigator.of(context).pushReplacementNamed(
              decision.routeName,
              arguments: decision.arguments,
            );
            return;
          }

          await TripPersistenceService().clearActiveTrip();
        }
      }
    } catch (e) {
      debugPrint(
        '[TripRecovery] ts=${DateTime.now().toIso8601String()} tripId=0 '
        'latency_ms=${DateTime.now().difference(recoveryStartedAt).inMilliseconds} result=error_$e',
      );
      debugPrint('⚠️ Error en recuperación de viaje: $e');
    }

    if (!mounted || !_isCurrentRoute) return;

    final startupDecision = await _resolveStartupRouteDecision();
    _navigateToStartupDecision(startupDecision);
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
    if (_showAnimatedSplash == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      );
    }

    if (_showAnimatedSplash == false) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SizedBox.expand(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _pulseController,
          _rotationController,
        ]),
        builder: (context, child) {
          return Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo circular con brillo animado y transición hero.
                  LogoHeroTransition(
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Transform.rotate(
                        angle: _rotationAnim.value,
                        child: AnimatedLogo(
                          size: 86,
                          glowOpacity:
                              Theme.of(context).brightness == Brightness.dark
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

                  // Nombre de la app con escala y aparición progresiva.
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
                                    ..shader =
                                        LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.primaryLight,
                                            AppColors.accent,
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ).createShader(
                                          const Rect.fromLTWH(0, 0, 200, 0),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 0),

                  // Subtítulo con aparición progresiva independiente.
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

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

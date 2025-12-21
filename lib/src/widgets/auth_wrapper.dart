// lib/src/widgets/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Iniciar animación
    _controller.repeat(reverse: true);

    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      // Primero verificar si es la primera vez que abre la app
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

      if (!mounted) return;

      // Si no ha completado el onboarding, mostrar pantalla introductoria
      if (!onboardingCompleted) {
        Navigator.of(context).pushReplacementNamed(RouteNames.onboarding);
        return;
      }

      // Verificar si hay una sesión guardada
      final session = await UserService.getSavedSession();

      if (!mounted) return;

      if (session != null && session['email'] != null) {
        // Verificar si tenemos el tipo de usuario guardado
        final tipoUsuarioGuardado = session['tipo_usuario'];

        if (tipoUsuarioGuardado != null) {
          // Usar el tipo guardado directamente para navegación más rápida
          if (tipoUsuarioGuardado == 'administrador') {
            // Debug: verificar ID del administrador
            print('AuthWrapper: Admin ID desde sesiÃ³n: ${session['id']}');
            
            // Para administradores, siempre usar los datos de la sesión que ya incluyen el ID
            Navigator.of(context).pushReplacementNamed(
              RouteNames.adminHome,
              arguments: {'admin_user': session},
            );
          } else if (tipoUsuarioGuardado == 'conductor') {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.conductorHome,
              arguments: {'conductor_user': session},
            );
          } else {
            // Cliente
            Navigator.of(context).pushReplacementNamed(
              RouteNames.home,
              arguments: {'email': session['email'], 'user': session},
            );
          }
        } else {
          // No hay tipo guardado, obtener perfil completo
          final profile = await UserService.getProfile(
            userId: session['id'] as int?,
            email: session['email'] as String?,
          );

          if (!mounted) return;

          if (profile != null && profile['success'] == true) {
            final user = profile['user'];
            final tipoUsuario = user?['tipo_usuario'] ?? 'cliente';

            // Actualizar la sesión con el tipo obtenido
            await UserService.saveSession(user);

            // Redirigir según el tipo de usuario
            if (tipoUsuario == 'administrador') {
              // Debug: verificar ID del administrador
              print('AuthWrapper: Admin ID desde perfil: ${user?['id']}');
              
              Navigator.of(context).pushReplacementNamed(
                RouteNames.adminHome,
                arguments: {'admin_user': user},
              );
            } else if (tipoUsuario == 'conductor') {
              Navigator.of(context).pushReplacementNamed(
                RouteNames.conductorHome,
                arguments: {'conductor_user': user},
              );
            } else {
              // Cliente
              Navigator.of(context).pushReplacementNamed(
                RouteNames.home,
                arguments: {'email': session['email'], 'user': user},
              );
            }
          } else {
            // Si no se pudo obtener el perfil, limpiar sesión y mostrar welcome
            await UserService.clearSession();
            Navigator.of(context).pushReplacementNamed(RouteNames.welcome);
          }
        }
      } else {
        // No hay sesiÃ³n, mostrar welcome
        Navigator.of(context).pushReplacementNamed(RouteNames.welcome);
      }
    } catch (e) {
      // En caso de error, mostrar welcome por defecto
      print('Error en _checkSession: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(RouteNames.welcome);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo con efecto de pulso y glow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow exterior pulsante
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            width: size.width * 0.32,
                            height: size.width * 0.32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF2196F3).withValues(alpha: 0.3),
                                  const Color(0xFF2196F3).withValues(alpha: 0.1),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Círculo de fondo con sombra
                        Container(
                          width: size.width * 0.28,
                          height: size.width * 0.28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF2196F3).withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.85],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2196F3),
                                    Color(0xFF1976D2),
                                  ],
                                ).createShader(bounds);
                              },
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 80,
                                height: 80,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Indicador de carga con diseño moderno
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Círculo exterior
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF2196F3).withValues(alpha: 0.3),
                              ),
                              value: null,
                            ),
                          ),
                          // Círculo interior
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF2196F3),
                              ),
                              value: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

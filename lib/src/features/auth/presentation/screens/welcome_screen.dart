// lib/src/features/auth/presentation/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/auth/google_auth_service.dart';
import 'package:viax/src/theme/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isGoogleLoading = false;
  
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await UserService.getSavedSession();
    if (session != null && mounted) {
      // Verificar si necesita ingresar teléfono
      final requiresPhone = await GoogleAuthService.checkRequiresPhone();
      if (requiresPhone && mounted) {
        Navigator.of(context).pushReplacementNamed(
          RouteNames.phoneRequired,
          arguments: session,
        );
      } else if (mounted) {
        Navigator.of(context).pushReplacementNamed(RouteNames.home);
      }
    }
  }
  
  /// Inicia sesión con Google usando el SDK nativo
  Future<void> _signInWithGoogle() async {
    if (_isGoogleLoading) return;
    
    setState(() {
      _isGoogleLoading = true;
    });
    
    try {
      // Usar el SDK de Google Sign-In directamente
      final result = await GoogleAuthService.signInWithGoogle();
      
      if (!mounted) return;
      
      if (result['cancelled'] == true) {
        // Usuario canceló, no mostrar error
        return;
      }
      
      if (result['success'] == true) {
        // Verificar si necesita teléfono
        if (result['requires_phone'] == true) {
          Navigator.of(context).pushReplacementNamed(
            RouteNames.phoneRequired,
            arguments: result['user'],
          );
        } else {
          // Determinar redirección basada en rol
          final user = result['user'];
          final tipoUsuario = user?['tipo_usuario'] ?? 'cliente';
          
          if (tipoUsuario == 'administrador') {
            Navigator.pushNamedAndRemoveUntil(
              context, 
              RouteNames.adminHome,
              (route) => false,
              arguments: {'admin_user': user},
            );
          } else if (tipoUsuario == 'conductor') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.conductorHome,
              (route) => false,
              arguments: {'conductor_user': user},
            );
          } else if (tipoUsuario == 'empresa') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.companyHome,
              (route) => false,
              arguments: {'user': user},
            );
          } else {
            // Cliente
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.home,
              (route) => false,
            );
          }
        }
      } else {
        _showErrorSnackBar(result['message'] ?? 'Error en la autenticación');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Column(
            children: [
              SizedBox(height: size.height * 0.12),
              
              // Icono de auto moderno con efecto de profundidad (entrance animation)
              EntranceFader(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.1, 0.8],
                    ),
                  ),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ).createShader(bounds);
                    },
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 85,
                      height: 85,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),

              EntranceFader(
                delay: const Duration(milliseconds: 160),
                child: Text(
                  'Bienvenido a Viax',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.displayMedium?.color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              EntranceFader(
                delay: const Duration(milliseconds: 240),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Viaja fácil, llega rápido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: size.height * 0.07),
              
              // Botones de autenticación
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Iniciar con Google
                    _buildSocialButton(
                      icon: _isGoogleLoading 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                            ),
                          )
                        : Image.asset(
                            'assets/images/google_logo.png',
                            height: 24,
                            width: 24,
                          ),
                      text: _isGoogleLoading ? 'Conectando...' : 'Continuar con Google',
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                        borderColor: isDark 
                          ? Colors.white.withValues(alpha: 0.3) 
                          : Colors.black.withValues(alpha: 0.2),
                      onPressed: _isGoogleLoading ? () {} : _signInWithGoogle,
                    ),
                    
                    const SizedBox(height: 14),
                    
                    /*
                    // Iniciar con Apple
                    _buildSocialButton(
                      icon: Icon(
                        Icons.apple,
                        color: Colors.white,
                        size: 24,
                      ),
                      text: 'Continuar con Apple',
                      backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFF000000),
                      textColor: Colors.white,
                        borderColor: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.transparent,
                      onPressed: () {
                        // TODO: Integrar Apple Sign-In
                      },
                    ),                    const SizedBox(height: 14),
                    */
                    
                    // Iniciar con correo
                    _buildSocialButton(
                      icon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      text: 'Continuar con correo',
                      backgroundColor: Colors.transparent,
                      textColor: AppColors.primary,
                      borderColor: AppColors.primary.withValues(alpha: 0.5),
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.emailAuth);
                      },
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Divider con texto
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '¿Tienes una empresa?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Botón de registro de empresa
                    _buildSocialButton(
                      icon: Icon(
                        Icons.business_outlined,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 24,
                      ),
                      text: 'Registrar empresa de transporte',
                      backgroundColor: Colors.transparent,
                      textColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? Colors.white24 : Colors.black26,
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.empresaRegister);
                      },
                    ),
                    
                    /*
                    const SizedBox(height: 14),
                    
                    // Iniciar con teléfono
                    _buildSocialButton(
                      icon: const Icon(
                        Icons.phone_iphone_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      text: 'Continuar con teléfono',
                      backgroundColor: AppColors.primary,
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.phoneAuth);
                      },
                    ),
                    */
                    
                    const SizedBox(height: 28),
                    
                    // Términos y condiciones
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'Al continuar, aceptas nuestros ',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            fontSize: 12,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Términos de Servicio',
                              style: TextStyle(
                                color: AppColors.primary.withValues(alpha: 0.9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' y '),
                            TextSpan(
                              text: 'Política de Privacidad',
                              style: TextStyle(
                                color: AppColors.primary.withValues(alpha: 0.9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String text,
    required Color backgroundColor,
    required Color textColor,
    Color borderColor = Colors.transparent,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: 1.2,
            ),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

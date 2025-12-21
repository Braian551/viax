import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';

class WelcomeSplashScreen extends StatefulWidget {
  const WelcomeSplashScreen({super.key});

  @override
  State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState();
}

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToHome() {
    Navigator.of(context).pushReplacementNamed(RouteNames.home);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, AppColors.lightSurface],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo y título animados
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo con brillo
                            Container(
                              width: size.width * 0.32,
                              height: size.width * 0.32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.25),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.9],
                                ),
                                boxShadow: [
                                  AppColors.primaryGlow(opacity: 0.15, blur: 30, spread: 8),
                                ],
                              ),
                              child: Center(
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return const LinearGradient(
                                      colors: [AppColors.primary, AppColors.primaryLight],
                                    ).createShader(bounds);
                                  },
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 80,
                                    height: 80,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Título de bienvenida
                            Text(
                              '¡Bienvenido a Ping Go!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.displayLarge?.color,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Subtítulo
                            Text(
                              'Tu cuenta ha sido creada exitosamente',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Estás listo para comenzar tu experiencia',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Botón de continuar
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _goToHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Comenzar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 24),
                        ],
                      ),
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
}

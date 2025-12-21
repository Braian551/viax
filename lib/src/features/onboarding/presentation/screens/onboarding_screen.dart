// lib/src/features/onboarding/presentation/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.motorcycle,
      title: 'Transporte RÃ¡pido y Seguro',
      description:
          'Viaja con conductores verificados en motos. Llega a tu destino rÃ¡pido evitando el trÃ¡fico.',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9900), Color(0xFFFFFF00)],
      ),
    ),
    OnboardingPage(
      icon: Icons.local_shipping_outlined,
      title: 'EnvÃ­os Express',
      description:
          'EnvÃ­a y recibe paquetes de forma rÃ¡pida y segura. Seguimiento en tiempo real de tus envÃ­os.',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9900), Color(0xFFFFFF00)],
      ),
    ),
    OnboardingPage(
      icon: Icons.route_outlined,
      title: 'Viajes Grabados',
      description:
          'Grabamos cada recorrido para tu seguridad. Comparte tu viaje en tiempo real con familiares.',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9900), Color(0xFFFFFF00)],
      ),
    ),
    OnboardingPage(
      icon: Icons.verified_user_outlined,
      title: 'Confianza Total',
      description:
          'Conductores verificados, pagos seguros y soporte 24/7. Tu seguridad es nuestra prioridad.',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9900), Color(0xFFFFFF00)],
      ),
    ),
    OnboardingPage(
      icon: Icons.star_outline,
      title: 'Calidad Garantizada',
      description:
          'Sistema de calificaciones bidireccional. Los mejores conductores, el mejor servicio.',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9900), Color(0xFFFFFF00)],
      ),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(RouteNames.welcome);
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo pequeÃ±o
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [Color(0xFFFFFF00), Color(0xFFFFDD00)],
                          ).createShader(bounds);
                        },
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Viax',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Skip button
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: const Text(
                        'Saltar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], size);
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildIndicator(index == _currentPage),
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Row(
                children: [
                  // Back button
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                            color: Color(0xFFFFFF00),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'AtrÃ¡s',
                          style: TextStyle(
                            color: Color(0xFFFFFF00),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  // Next/Start button
                  Expanded(
                    flex: _currentPage > 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFF00),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Comenzar'
                                : 'Siguiente',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.black,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Icon with gradient and glow effect
          Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFFF00).withValues(alpha: 0.2),
                  const Color(0xFFFFFF00).withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: page.gradient,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(page.icon, size: 80, color: Colors.black),
              ),
            ),
          ),

          const SizedBox(height: 60),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFFF00) : Colors.white30,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

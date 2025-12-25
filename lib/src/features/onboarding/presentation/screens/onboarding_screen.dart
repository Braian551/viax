import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'dart:ui';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Initial Entrance Animation
  bool _isInitialized = false;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.directions_car_filled_rounded,
      title: 'Tu Transporte Ideal',
      description:
          'Conecta con conductores verificados y llega a tu destino de manera rápida, segura y cómoda.',
    ),
    OnboardingPage(
      icon: Icons.map_rounded,
      title: 'Seguimiento en Vivo',
      description:
          'Monitorea tu viaje en tiempo real y comparte tu ubicación con amigos y familiares para mayor tranquilidad.',
    ),
    OnboardingPage(
      icon: Icons.verified_user_rounded,
      title: 'Seguridad Garantizada',
      description:
          'Viaja sin preocupaciones. Todos nuestros conductores pasan por un riguroso proceso de verificación.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Simple delay to trigger entrance animation for first render
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isInitialized = true);
    });
  }

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
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background Gradient Blobs
          // Use AnimatedPositioned for subtle movement if desired, but static is fine for fluidity focusing on page view
          Positioned(
            top: -100,
            right: -100,
            child: _buildGradientBlob(size, AppColors.primary.withOpacity(0.2)),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _buildGradientBlob(size, AppColors.accent.withOpacity(0.15)),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header (Skip Button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 28,
                            height: 28,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.flash_on, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Viax',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _currentPage < _pages.length - 1 ? 1.0 : 0.0,
                        child: TextButton(
                          onPressed: _currentPage < _pages.length - 1 ? _completeOnboarding : null,
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white60 : Colors.black54,
                          ),
                          child: const Text('Saltar', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      // Apply scroll-driven animations individually per page item
                      // But for standard fluidity, standard PageView swipe is best.
                      // We can add a simple entrance animation for the FIRST load.
                      
                      return AnimatedOpacity(
                         duration: const Duration(milliseconds: 600),
                         opacity: _isInitialized ? 1.0 : 0.0,
                         child: _buildPageContent(
                          context,
                          _pages[index],
                          size,
                          textColor,
                          isDark,
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicators
                      Row(
                        children: List.generate(
                          _pages.length,
                          (index) => _buildIndicator(index == _currentPage, isDark),
                        ),
                      ),

                      // Next Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.fastOutSlowIn,
                        height: 60,
                        width: _currentPage == _pages.length - 1 ? 160 : 60,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.4),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: _currentPage == _pages.length - 1
                              ? const Row(
                                  key: ValueKey('start'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Comenzar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                                  ],
                                )
                              : const Icon(key: ValueKey('next'), Icons.arrow_forward_rounded, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBlob(Size size, Color color) {
    return Container(
      width: size.width * 0.8,
      height: size.width * 0.8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildPageContent(
    BuildContext context,
    OnboardingPage page,
    Size size,
    Color textColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Icon Container
          Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark 
                  ? AppColors.darkSurface 
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Icon(
                  page.icon,
                  size: size.width * 0.25,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),

          // Text Content
          Column(
            children: [
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive 
            ? AppColors.primary 
            : (isDark ? Colors.white24 : Colors.black12),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}

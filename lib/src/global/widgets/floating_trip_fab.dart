import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../services/active_trip_navigation_service.dart';

/// FAB flotante que aparece cuando hay un viaje activo y el usuario
/// navega a otras pantallas de la app.
/// 
/// Características:
/// - Animación de pulso para llamar la atención
/// - Arrastrable para que el usuario lo posicione donde prefiera
/// - Muestra información del viaje al mantener presionado
/// - Desaparece automáticamente al regresar a la pantalla del viaje
class FloatingTripFab extends StatefulWidget {
  const FloatingTripFab({super.key});

  @override
  State<FloatingTripFab> createState() => _FloatingTripFabState();
}

class _FloatingTripFabState extends State<FloatingTripFab>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  StreamSubscription<bool>? _stateSubscription;
  bool _isVisible = false;
  
  // Posición del FAB (draggable)
  Offset _position = const Offset(20, 0); // Se ajustará en initState
  bool _isDragging = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    
    _setupAnimations();
    _listenToTripState();
    
    // Posición inicial se establecerá después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _position = Offset(
            size.width - 80,
            size.height * 0.7,
          );
        });
      }
    });
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  void _listenToTripState() {
    final service = ActiveTripNavigationService();
    
    // Estado inicial
    _updateVisibility(service.shouldShowFloatingFab);
    
    // Escuchar cambios
    _stateSubscription = service.stateStream.listen(_updateVisibility);
  }

  void _updateVisibility(bool shouldShow) {
    if (shouldShow && !_isVisible) {
      setState(() => _isVisible = true);
      _scaleController.forward();
    } else if (!shouldShow && _isVisible) {
      _scaleController.reverse().then((_) {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    ActiveTripNavigationService().navigateToActiveTrip(context);
  }

  void _onLongPress() {
    HapticFeedback.heavyImpact();
    setState(() => _isExpanded = true);
    
    // Auto-cerrar después de 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isExpanded) {
        setState(() => _isExpanded = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripData = ActiveTripNavigationService().activeTripData;
    
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onPanStart: (_) {
            setState(() => _isDragging = true);
            _pulseController.stop();
          },
          onPanUpdate: (details) {
            setState(() {
              _position = Offset(
                _position.dx + details.delta.dx,
                _position.dy + details.delta.dy,
              );
            });
          },
          onPanEnd: (_) {
            setState(() => _isDragging = false);
            _pulseController.repeat(reverse: true);
            _snapToEdge();
          },
          onTap: _onTap,
          onLongPress: _onLongPress,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isDragging ? 1.1 : _pulseAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: _isExpanded ? 16 : 0,
                    vertical: _isExpanded ? 12 : 0,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(_isExpanded ? 20 : 30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isExpanded
                      ? _buildExpandedContent(tripData, isDark)
                      : _buildCollapsedContent(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.directions_car_rounded,
            color: Colors.white,
            size: 28,
          ),
          // Indicador de viaje activo
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(ActiveTripData? tripData, bool isDark) {
    final isClient = tripData?.isClient ?? true;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isClient ? Icons.directions_car_rounded : Icons.person_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isClient ? 'Viaje en curso' : 'Pasajero esperando',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Toca para volver',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white.withValues(alpha: 0.8),
          size: 16,
        ),
      ],
    );
  }

  void _snapToEdge() {
    final size = MediaQuery.of(context).size;
    final center = size.width / 2;
    
    // Determinar a qué borde acercar
    final targetX = _position.dx < center
        ? 16.0 // Izquierda
        : size.width - 72.0; // Derecha
    
    // Limitar verticalmente
    final targetY = _position.dy.clamp(
      MediaQuery.of(context).padding.top + 60,
      size.height - MediaQuery.of(context).padding.bottom - 140,
    );
    
    setState(() {
      _position = Offset(targetX, targetY);
    });
  }
}

/// Widget overlay que envuelve la app y muestra el FAB cuando corresponde
class ActiveTripOverlay extends StatelessWidget {
  final Widget child;

  const ActiveTripOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const FloatingTripFab(),
      ],
    );
  }
}

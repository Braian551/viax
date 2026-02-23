import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../services/active_trip_navigation_service.dart';
import '../services/trip_status_navigation_service.dart';
import '../../features/user/services/trip_request_service.dart';

/// Muestra una alerta indicando que hay un viaje en curso
/// y permite navegar directamente al viaje activo
/// 
/// [userId] - ID del usuario para buscar el viaje activo si no está en memoria
void showActiveTripAlert(
  BuildContext context, {
  required bool isConductor,
  int? userId,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final navService = ActiveTripNavigationService();
  
  showDialog(
    context: context,
    builder: (dialogContext) => _ActiveTripAlertDialog(
      isDark: isDark,
      isConductor: isConductor,
      userId: userId,
      navService: navService,
      parentContext: context,
    ),
  );
}

class _ActiveTripAlertDialog extends StatefulWidget {
  final bool isDark;
  final bool isConductor;
  final int? userId;
  final ActiveTripNavigationService navService;
  final BuildContext parentContext;

  const _ActiveTripAlertDialog({
    required this.isDark,
    required this.isConductor,
    this.userId,
    required this.navService,
    required this.parentContext,
  });

  @override
  State<_ActiveTripAlertDialog> createState() => _ActiveTripAlertDialogState();
}

class _ActiveTripAlertDialogState extends State<_ActiveTripAlertDialog> {
  bool _isLoading = false;

  Future<void> _navigateToActiveTrip() async {
    // Si el servicio ya tiene datos del viaje, usamos eso
    if (widget.navService.hasActiveTrip) {
      Navigator.pop(context);
      widget.navService.navigateToActiveTrip(widget.parentContext);
      return;
    }

    // Si no hay datos, necesitamos obtenerlos del backend
    if (widget.userId == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final role = widget.isConductor ? 'conductor' : 'cliente';
      final result = await TripRequestService.checkActiveTrip(
        userId: widget.userId!,
        role: role,
      );

      if (!mounted) return;

      if (result['success'] == true && (result['has_active'] == true || result['trip'] != null)) {
        final tripData = result['trip'];
        if (tripData != null) {
          debugPrint('✅ [ActiveTripAlert] Navigating to active trip: $tripData');
          
          Navigator.pop(context);

          final navigator = ActiveTripNavigationService.navigatorKey.currentState;
          if (navigator == null) {
            if (mounted) {
              Navigator.pop(context);
            }
            return;
          }

          if (widget.isConductor) {
            final decision = TripStatusNavigationService.resolveConductorNavigation(
              trip: Map<String, dynamic>.from(tripData as Map),
              fallbackConductorId: widget.userId ?? 0,
            );

            if (decision != null) {
              await navigator.pushNamed(
                decision.routeName,
                arguments: decision.arguments,
              );
            }
          } else {
            final decision = TripStatusNavigationService.resolveUserNavigation(
              trip: Map<String, dynamic>.from(tripData as Map),
              fallbackClienteId: widget.userId ?? 0,
            );

            if (decision != null) {
              await navigator.pushNamed(
                decision.routeName,
                arguments: decision.arguments,
              );
            }
          }
          return;
        }
      }
      
      // Si no se encontró viaje activo, solo cerrar
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error navigating to active trip: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo con efecto blur
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  color: (widget.isDark ? const Color(0xFF1E1E1E) : Colors.white)
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (widget.isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_rounded,
                        size: 32,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Título
                    Text(
                      'Viaje en curso',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Mensaje
                    Text(
                      widget.isConductor
                          ? 'No puedes desconectarte ni conectarte mientras tienes un viaje activo. Finaliza el viaje actual primero.'
                          : 'Tienes un viaje en curso. No puedes solicitar otro viaje hasta que el actual finalice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Botón Ir al viaje (principal)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _navigateToActiveTrip,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          _isLoading ? 'Cargando...' : 'Ir al viaje',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    
                    // Botón Cerrar (secundario)
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: widget.isDark ? Colors.white60 : Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


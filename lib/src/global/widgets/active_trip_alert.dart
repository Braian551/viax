import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../services/active_trip_navigation_service.dart';
import '../../features/user/services/trip_request_service.dart';
import '../../routes/route_names.dart';

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
          
          // Función auxiliar para parsear enteros seguros
          int parseInt(dynamic value) {
            if (value == null) return 0;
            if (value is int) return value;
            return int.tryParse(value.toString()) ?? 0;
          }

          // Función auxiliar para parsear doubles seguros
          double parseDouble(dynamic value) {
            if (value == null) return 0.0;
            if (value is double) return value;
            if (value is int) return value.toDouble();
            return double.tryParse(value.toString()) ?? 0.0;
          }
          
          final navigator = ActiveTripNavigationService.navigatorKey.currentState;
          if (navigator == null) {
            if (mounted) {
              Navigator.pop(context);
            }
            return;
          }

          // Navegar a la pantalla correcta según el rol
          if (widget.isConductor) {
            await navigator.pushNamed(
              RouteNames.conductorActiveTrip,
              arguments: {
                'conductorId': widget.userId,
                'solicitudId': parseInt(tripData['id']),
                'origenLat': parseDouble(tripData['latitud_recogida'] ?? tripData['latitud_origen']),
                'origenLng': parseDouble(tripData['longitud_recogida'] ?? tripData['longitud_origen']),
                'destinoLat': parseDouble(tripData['latitud_destino']),
                'destinoLng': parseDouble(tripData['longitud_destino']),
                'direccionOrigen': tripData['direccion_recogida'] ?? tripData['direccion_origen'] ?? '',
                'direccionDestino': tripData['direccion_destino'] ?? '',
                'clienteNombre': tripData['cliente_nombre'],
                'clienteFoto': tripData['cliente_foto'],
                'clienteId': parseInt(tripData['cliente_id']),
                'initialTripStatus': tripData['estado'],
              },
            );
          } else {
            // Para clientes, verificar el estado del viaje
            final tripStatus = tripData['estado']?.toString() ?? '';
            final shouldGoToMeetingPoint =
                tripStatus == 'aceptada' ||
                tripStatus == 'conductor_asignado' ||
                tripStatus == 'en_camino' ||
                tripStatus == 'conductor_llego';
            
            if (tripStatus == 'pendiente') {
              // Viaje esperando conductor - ir a WaitingForDriverScreen
              await navigator.pushNamed(
                '/user/waiting_driver',
                arguments: {
                  'solicitud_id': parseInt(tripData['id']),
                  'cliente_id': widget.userId,
                  'direccion_origen': tripData['direccion_recogida'] ?? tripData['direccion_origen'] ?? '',
                  'direccion_destino': tripData['direccion_destino'] ?? '',
                },
              );
            } else if (shouldGoToMeetingPoint) {
              await navigator.pushNamed(
                RouteNames.userTripAccepted,
                arguments: {
                  'solicitudId': parseInt(tripData['id']),
                  'clienteId': widget.userId,
                  'latitudOrigen': parseDouble(tripData['latitud_recogida'] ?? tripData['latitud_origen']),
                  'longitudOrigen': parseDouble(tripData['longitud_recogida'] ?? tripData['longitud_origen']),
                  'direccionOrigen': tripData['direccion_recogida'] ?? tripData['direccion_origen'] ?? '',
                  'latitudDestino': parseDouble(tripData['latitud_destino']),
                  'longitudDestino': parseDouble(tripData['longitud_destino']),
                  'direccionDestino': tripData['direccion_destino'] ?? '',
                  'conductorInfo': tripData['conductor'],
                },
              );
            } else {
              // Viaje con conductor asignado - ir a UserActiveTripScreen
              await navigator.pushNamed(
                RouteNames.userActiveTrip,
                arguments: {
                  'solicitudId': parseInt(tripData['id']),
                  'clienteId': widget.userId,
                  'origenLat': parseDouble(tripData['latitud_recogida'] ?? tripData['latitud_origen']),
                  'origenLng': parseDouble(tripData['longitud_recogida'] ?? tripData['longitud_origen']),
                  'direccionOrigen': tripData['direccion_recogida'] ?? tripData['direccion_origen'] ?? '',
                  'destinoLat': parseDouble(tripData['latitud_destino']),
                  'destinoLng': parseDouble(tripData['longitud_destino']),
                  'direccionDestino': tripData['direccion_destino'] ?? '',
                  'conductorInfo': tripData['conductor'],
                },
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


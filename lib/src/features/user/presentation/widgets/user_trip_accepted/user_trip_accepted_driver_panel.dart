import 'package:flutter/material.dart';
import '../glass_widgets.dart';

class UserTripAcceptedDriverPanel extends StatelessWidget {
  final Map<String, dynamic>? conductor;
  final double? conductorEtaMinutes;
  final double? conductorDistanceKm;
  final VoidCallback onCall;
  final VoidCallback onCancelChat;
  final bool isDark;
  final int unreadCount;

  const UserTripAcceptedDriverPanel({
    super.key,
    required this.conductor,
    required this.conductorEtaMinutes,
    required this.conductorDistanceKm,
    required this.onCall,
    required this.onCancelChat,
    required this.isDark,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (conductor == null) {
      return const SizedBox.shrink();
    }

    final nombre = conductor!['nombre'] as String? ?? 'Conductor';
    final foto = conductor!['foto'] as String?;
    final calificacion =
        (conductor!['calificacion'] as num?)?.toDouble() ?? 4.5;
    final vehiculo = conductor!['vehiculo'] as Map<String, dynamic>?;

    return DriverInfoCard(
      nombre: nombre,
      foto: foto,
      calificacion: calificacion,
      vehiculo: vehiculo,
      etaMinutes: conductorEtaMinutes,
      distanceKm: conductorDistanceKm,
      onCall: onCall,
      onMessage: onCancelChat,
      isDark: isDark,
      unreadCount: unreadCount,
    );
  }
}

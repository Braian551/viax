import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/app_colors.dart';
import '../../../services/conductor_trips_service.dart';
import 'trip_status_badge.dart';
import 'trip_route_info.dart';

/// Card de viaje con diseño glassmorphism
/// Muestra la información resumida de un viaje con animaciones
class TripHistoryCard extends StatefulWidget {
  final TripModel trip;
  final VoidCallback onTap;
  final int index;

  const TripHistoryCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.index = 0,
  });

  @override
  State<TripHistoryCard> createState() => _TripHistoryCardState();
}

class _TripHistoryCardState extends State<TripHistoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index * 100).clamp(0, 300)),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: _buildCard(isDark),
    );
  }

  Widget _buildCard(bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a', 'es');
    final dateStr = widget.trip.fechaCompletado != null
        ? dateFormat.format(widget.trip.fechaCompletado!)
        : dateFormat.format(widget.trip.fechaSolicitud);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkCard.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildCardContent(isDark, dateStr),
                  _buildEarningsFooter(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(bool isDark, String dateStr) {
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? Colors.white70 : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estado y fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TripStatusBadge(status: widget.trip.estado),
              Text(
                dateStr,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Información del cliente
          _buildCustomerInfo(textColor, subtitleColor, isDark),
          const SizedBox(height: 20),

          // Ruta
          TripRouteInfo(
            origin: widget.trip.origen,
            destination: widget.trip.destino,
          ),
          const SizedBox(height: 16),

          // Stats
          _buildTripStats(subtitleColor, isDark),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(Color textColor, Color subtitleColor, bool isDark) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.trip.clienteNombre.isNotEmpty
                  ? widget.trip.clienteNombre[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        
        // Nombre y calificación
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.trip.clienteNombreCompleto,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (widget.trip.calificacion != null)
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.trip.calificacionDouble.toStringAsFixed(1),
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Sin calificar',
                  style: TextStyle(
                    color: subtitleColor.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),

        // Tipo de servicio
        _buildServiceTypeBadge(isDark),
      ],
    );
  }

  Widget _buildServiceTypeBadge(bool isDark) {
    final tipoServicio = widget.trip.tipoServicio.toLowerCase();
    IconData icon;
    String label;

    switch (tipoServicio) {
      case 'viaje':
      case 'ride':
        icon = Icons.directions_car_rounded;
        label = 'Viaje';
        break;
      case 'envio':
      case 'delivery':
        icon = Icons.local_shipping_rounded;
        label = 'Envío';
        break;
      case 'mudanza':
      case 'moving':
        icon = Icons.home_work_rounded;
        label = 'Mudanza';
        break;
      default:
        icon = Icons.local_taxi_rounded;
        label = widget.trip.tipoServicio;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStats(Color subtitleColor, bool isDark) {
    return Row(
      children: [
        if (widget.trip.distanciaKm != null)
          _StatBadge(
            icon: Icons.route_rounded,
            text: '${widget.trip.distanciaKm!.toStringAsFixed(1)} km',
            isDark: isDark,
          ),
        if (widget.trip.distanciaKm != null && widget.trip.duracionEstimada != null)
          const SizedBox(width: 12),
        if (widget.trip.duracionEstimada != null)
          _StatBadge(
            icon: Icons.access_time_rounded,
            text: '${widget.trip.duracionEstimada} min',
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildEarningsFooter(bool isDark) {
    final ganancia = widget.trip.precioFinal ?? widget.trip.precioEstimado ?? 0;
    final isCompleted = widget.trip.estado.toLowerCase() == 'completada' ||
        widget.trip.estado.toLowerCase() == 'entregado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isCompleted ? 'Ganancia del viaje' : 'Viaje cancelado',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              if (isCompleted)
                Text(
                  '+',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                '\$${ganancia.toStringAsFixed(0)}',
                style: TextStyle(
                  color: isCompleted ? AppColors.success : AppColors.error,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _StatBadge({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

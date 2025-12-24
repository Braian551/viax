import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/app_colors.dart';
import '../../../services/conductor_trips_service.dart';
import 'trip_status_badge.dart';
import 'trip_route_info.dart';

/// Bottom sheet con detalles completos del viaje
/// Diseño profesional con animaciones suaves
class TripDetailBottomSheet extends StatefulWidget {
  final TripModel trip;

  const TripDetailBottomSheet({
    super.key,
    required this.trip,
  });

  /// Muestra el bottom sheet con animación
  /// [isDark] es opcional, el tema se detecta automáticamente del contexto
  static Future<void> show(BuildContext context, TripModel trip, {bool isDark = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => TripDetailBottomSheet(trip: trip),
    );
  }

  @override
  State<TripDetailBottomSheet> createState() => _TripDetailBottomSheetState();
}

class _TripDetailBottomSheetState extends State<TripDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
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
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, screenHeight * 0.7 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _buildContent(context, scrollController, isDark);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildHandle(isDark),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  physics: const BouncingScrollPhysics(),
                  child: _buildBody(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? Colors.white70 : AppColors.lightTextSecondary;
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'es');
    final timeFormat = DateFormat('hh:mm a', 'es');

    final fullDate = widget.trip.fechaCompletado != null
        ? dateFormat.format(widget.trip.fechaCompletado!)
        : dateFormat.format(widget.trip.fechaSolicitud);
    final fullTime = widget.trip.fechaCompletado != null
        ? timeFormat.format(widget.trip.fechaCompletado!)
        : timeFormat.format(widget.trip.fechaSolicitud);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Detalles del Viaje',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            TripStatusBadge(status: widget.trip.estado),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Viaje #${widget.trip.id}',
          style: TextStyle(
            color: subtitleColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),

        // Cliente info card
        _buildClientCard(isDark, textColor, subtitleColor),
        const SizedBox(height: 20),

        // Fecha y hora
        _buildDetailTile(
          icon: Icons.calendar_today_rounded,
          title: 'Fecha',
          value: fullDate,
          isDark: isDark,
        ),
        _buildDetailTile(
          icon: Icons.access_time_rounded,
          title: 'Hora',
          value: fullTime,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // Ruta
        _buildSectionTitle('Ruta del Viaje', textColor),
        const SizedBox(height: 12),
        _buildRouteCard(isDark),
        const SizedBox(height: 20),

        // Estadísticas
        _buildSectionTitle('Detalles del Trayecto', textColor),
        const SizedBox(height: 12),
        _buildStatsGrid(isDark),
        const SizedBox(height: 20),

        // Ganancia
        _buildEarningsCard(isDark, textColor),
        const SizedBox(height: 24),

        // Botón cerrar
        _buildCloseButton(context, isDark),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildClientCard(bool isDark, Color textColor, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar grande
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
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
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.clienteNombreCompleto,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.trip.calificacion != null)
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < widget.trip.calificacion!
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                      const SizedBox(width: 8),
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
                    'Sin calificación',
                    style: TextStyle(
                      color: subtitleColor.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? Colors.white70 : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: TripRouteInfo(
        origin: widget.trip.origen,
        destination: widget.trip.destino,
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        if (widget.trip.distanciaKm != null)
          Expanded(
            child: _buildStatCard(
              icon: Icons.route_rounded,
              label: 'Distancia',
              value: '${widget.trip.distanciaKm!.toStringAsFixed(1)} km',
              isDark: isDark,
            ),
          ),
        if (widget.trip.distanciaKm != null && widget.trip.duracionEstimada != null)
          const SizedBox(width: 12),
        if (widget.trip.duracionEstimada != null)
          Expanded(
            child: _buildStatCard(
              icon: Icons.timer_rounded,
              label: 'Duración',
              value: '${widget.trip.duracionEstimada} min',
              isDark: isDark,
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? Colors.white70 : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(bool isDark, Color textColor) {
    final ganancia = widget.trip.precioFinal ?? widget.trip.precioEstimado ?? 0;
    final isCompleted = widget.trip.estado.toLowerCase() == 'completada' ||
        widget.trip.estado.toLowerCase() == 'entregado';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCompleted
              ? [
                  AppColors.success.withValues(alpha: 0.15),
                  AppColors.success.withValues(alpha: 0.05),
                ]
              : [
                  AppColors.error.withValues(alpha: 0.15),
                  AppColors.error.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCompleted ? 'Ganancia Total' : 'Viaje Cancelado',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isCompleted
                    ? 'Pago completado'
                    : 'No se realizó cobro',
                style: TextStyle(
                  color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (isCompleted)
                Text(
                  '+',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                '\$${ganancia.toStringAsFixed(0)}',
                style: TextStyle(
                  color: isCompleted ? AppColors.success : AppColors.error,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: AppColors.primary.withValues(alpha: 0.5),
        ),
        child: const Text(
          'Cerrar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

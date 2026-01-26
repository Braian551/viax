import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../services/user_trips_service.dart';
import '../trip_preview/trip_price_formatter.dart';
import 'trip_conductor_avatar.dart';

/// Tarjeta de viaje con diseño glassmorphism y animaciones
class TripHistoryCard extends StatefulWidget {
  final UserTripModel trip;
  final VoidCallback? onTap;
  final int index;
  final bool isDark;

  const TripHistoryCard({
    super.key,
    required this.trip,
    this.onTap,
    this.index = 0,
    this.isDark = false,
  });

  @override
  State<TripHistoryCard> createState() => _TripHistoryCardState();
}

class _TripHistoryCardState extends State<TripHistoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index * 80)),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    if (widget.trip.isCompletado) return AppColors.success;
    if (widget.trip.isCancelado) return AppColors.error;
    return AppColors.warning;
  }

  IconData _getStatusIcon() {
    if (widget.trip.isCompletado) return Icons.check_circle_rounded;
    if (widget.trip.isCancelado) return Icons.cancel_rounded;
    return Icons.schedule_rounded;
  }

  IconData _getServiceIcon() {
    switch (widget.trip.tipoServicio.toLowerCase()) {
      case 'mudanza':
        return Icons.home_work_rounded;
      case 'mandado':
        return Icons.shopping_bag_rounded;
      case 'transporte':
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final backgroundColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final chipBgColor = isDark ? AppColors.darkSurface : AppColors.lightBackground;
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    backgroundColor.withOpacity(0.95),
                    backgroundColor.withOpacity(0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withOpacity(0.3) 
                        : AppColors.primary.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: _getStatusColor().withOpacity(isDark ? 0.2 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Tipo de servicio + Estado + Precio
                        Row(
                          children: [
                            // Icono del servicio
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getServiceIcon(),
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Tipo de servicio
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _capitalize(widget.trip.tipoServicio),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(widget.trip.fechaSolicitud),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Precio
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCurrency(widget.trip.precioFinal > 0
                                      ? widget.trip.precioFinal
                                      : widget.trip.precioEstimado),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildStatusChip(),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Divider con gradiente
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary.withOpacity(isDark ? 0.3 : 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Origen y Destino
                        _buildLocationRow(
                          icon: Icons.radio_button_checked_rounded,
                          iconColor: AppColors.success,
                          text: widget.trip.origen,
                          isOrigin: true,
                          textColor: textColor,
                        ),
                        // Línea conectora
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: Container(
                            width: 2,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.success.withOpacity(0.3),
                                  AppColors.error.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _buildLocationRow(
                          icon: Icons.location_on_rounded,
                          iconColor: AppColors.error,
                          text: widget.trip.destino,
                          isOrigin: false,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 12),
                        // Info adicional
                        Row(
                          children: [
                            if (widget.trip.distanciaKm != null) ...[
                              _buildInfoChip(
                                Icons.straighten_rounded,
                                '${widget.trip.distanciaKm!.toStringAsFixed(1)} km',
                                chipBgColor,
                                textColor,
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (widget.trip.duracionMinutos != null) ...[
                              _buildInfoChip(
                                Icons.timer_rounded,
                                '${widget.trip.duracionMinutos} min',
                                chipBgColor,
                                textColor,
                              ),
                              const SizedBox(width: 8),
                            ],
                            _buildInfoChip(
                              Icons.payments_rounded,
                              _capitalize(widget.trip.metodoPago),
                              chipBgColor,
                              textColor,
                            ),
                          ],
                        ),
                        // Conductor (si existe)
                        if (widget.trip.conductorNombre != null) ...[
                          const SizedBox(height: 12),
                          _buildConductorInfo(chipBgColor, textColor, secondaryTextColor),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            widget.trip.estadoFormateado,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isOrigin,
    required Color textColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text.isNotEmpty ? text : 'Dirección no disponible',
            style: TextStyle(
              fontSize: 13,
              color: textColor.withOpacity(0.8),
              fontWeight: isOrigin ? FontWeight.w500 : FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConductorInfo(Color bgColor, Color textColor, Color secondaryColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          TripConductorAvatar(
            photoUrl: widget.trip.conductorFoto,
            conductorName: widget.trip.conductorNombreCompleto,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.conductorNombreCompleto,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (widget.trip.calificacionConductor != null)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.warning, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        widget.trip.calificacionConductor!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: textColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

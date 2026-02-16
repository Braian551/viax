import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../trip_preview/trip_price_formatter.dart';
import '../../../services/user_trips_service.dart';
import 'trip_conductor_avatar.dart';

/// Bottom Sheet con detalles del viaje
class TripDetailBottomSheet extends StatefulWidget {
  final UserTripModel trip;
  final bool isDark;

  const TripDetailBottomSheet({
    super.key,
    required this.trip,
    this.isDark = false,
  });

  /// Método estático para mostrar el bottom sheet
  static void show(BuildContext context, UserTripModel trip, {bool isDark = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripDetailBottomSheet(trip: trip, isDark: isDark),
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

    _slideAnimation = Tween<double>(begin: 0.3, end: 0.0).animate(
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
    final backgroundColor = widget.isDark 
        ? AppColors.darkSurface 
        : Colors.white;
    final handleColor = widget.isDark 
        ? Colors.grey.shade600 
        : Colors.grey.shade300;
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildStatusBanner(),
                            const SizedBox(height: 24),
                            _buildRouteSection(),
                            const SizedBox(height: 24),
                            _buildDetailsSection(),
                            const SizedBox(height: 24),
                            _buildPaymentSection(),
                            if (widget.trip.conductorNombre != null) ...[
                              const SizedBox(height: 24),
                              _buildConductorSection(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final textColor = widget.isDark 
        ? AppColors.darkTextPrimary 
        : AppColors.lightTextPrimary;
    final bgColor = widget.isDark 
        ? AppColors.darkBackground 
        : AppColors.lightBackground;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _getServiceIcon(),
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _capitalize(widget.trip.tipoServicio),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatFullDate(widget.trip.fechaSolicitud),
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: textColor),
          style: IconButton.styleFrom(
            backgroundColor: bgColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final statusColor = _getStatusColor();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(), color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.estadoFormateado,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                if (widget.trip.isCompletado && widget.trip.fechaCompletado != null)
                  Text(
                    'Completado el ${_formatFullDate(widget.trip.fechaCompletado)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    final textColor = widget.isDark 
        ? AppColors.darkTextPrimary 
        : AppColors.lightTextPrimary;
    final bgColor = widget.isDark 
        ? AppColors.darkBackground.withOpacity(0.5) 
        : AppColors.lightBackground.withOpacity(0.5);
    final borderColor = widget.isDark ? AppColors.darkSurface : Colors.white;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ruta',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          // Origen
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 2),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Origen',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.trip.origen.isNotEmpty 
                          ? widget.trip.origen 
                          : 'No disponible',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destino',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.trip.destino.isNotEmpty 
                          ? widget.trip.destino 
                          : 'No disponible',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    final textColor = widget.isDark 
        ? AppColors.darkTextPrimary 
        : AppColors.lightTextPrimary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalles del viaje',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (widget.trip.distanciaKm != null)
              Expanded(
                child: _buildDetailCard(
                  icon: Icons.straighten_rounded,
                  label: 'Distancia',
                  value: '${widget.trip.distanciaKm!.toStringAsFixed(1)} km',
                ),
              ),
            if (widget.trip.duracionMinutos != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailCard(
                  icon: Icons.timer_rounded,
                  label: 'Duración',
                  value: '${widget.trip.duracionMinutos} min',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final textColor = widget.isDark 
        ? AppColors.darkTextPrimary 
        : AppColors.lightTextPrimary;
    final cardColor = widget.isDark 
        ? AppColors.darkSurface.withOpacity(0.6) 
        : Colors.white;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(widget.isDark ? 0.2 : 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withOpacity(0.5),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    final textColor = widget.isDark 
        ? AppColors.darkTextPrimary 
        : AppColors.lightTextPrimary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(widget.isDark ? 0.1 : 0.05),
            AppColors.accent.withOpacity(widget.isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(widget.isDark ? 0.2 : 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Información de pago',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPaymentRow('Método de pago', _capitalize(widget.trip.metodoPago)),
          const SizedBox(height: 8),
          _buildPaymentRow(
            'Precio estimado',
            formatCurrency(widget.trip.precioEstimado),
          ),
          if (widget.trip.precioFinal > 0 && 
              widget.trip.precioFinal != widget.trip.precioEstimado) ...[
            const SizedBox(height: 8),
            _buildPaymentRow(
              'Precio final',
              formatCurrency(widget.trip.precioFinal),
              isHighlighted: true,
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: textColor.withOpacity(0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total pagado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                formatCurrency(widget.trip.precioFinal > 0 
                    ? widget.trip.precioFinal 
                    : widget.trip.precioEstimado),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Estado del pago
          Row(
            children: [
              Icon(
                widget.trip.pagoConfirmado 
                    ? Icons.verified_rounded 
                    : Icons.pending_rounded,
                color: widget.trip.pagoConfirmado 
                    ? AppColors.success 
                    : AppColors.warning,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                widget.trip.pagoConfirmado 
                    ? 'Pago confirmado' 
                    : 'Pago pendiente',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.trip.pagoConfirmado 
                      ? AppColors.success 
                      : AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isHighlighted = false}) {
    final textColor = widget.isDark 
        ? AppColors.darkTextPrimary 
        : AppColors.lightTextPrimary;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: textColor.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            color: isHighlighted ? AppColors.primary : textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildConductorSection() {
    final textColor = widget.isDark 
        ? AppColors.darkTextPrimary 
        : AppColors.lightTextPrimary;
    final bgColor = widget.isDark 
        ? AppColors.darkBackground.withOpacity(0.5) 
        : AppColors.lightBackground.withOpacity(0.5);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          TripConductorAvatar(
            photoUrl: widget.trip.conductorFoto,
            conductorName: widget.trip.conductorNombreCompleto,
            radius: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu conductor',
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.trip.conductorNombreCompleto,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (widget.trip.calificacionConductor != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        final rating = widget.trip.calificacionConductor!;
                        return Icon(
                          index < rating.floor() 
                              ? Icons.star_rounded 
                              : (index < rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                          color: AppColors.warning,
                          size: 16,
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        widget.trip.calificacionConductor!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatFullDate(DateTime? date) {
    if (date == null) return 'Fecha no disponible';
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${days[date.weekday - 1]} ${date.day} de ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

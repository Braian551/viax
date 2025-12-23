import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Estado de verificación del vehículo
class VehicleStatusCard extends StatefulWidget {
  final bool isVerified;
  final String? statusMessage;
  final VoidCallback? onVerify;

  const VehicleStatusCard({
    super.key,
    this.isVerified = false,
    this.statusMessage,
    this.onVerify,
  });

  @override
  State<VehicleStatusCard> createState() => _VehicleStatusCardState();
}

class _VehicleStatusCardState extends State<VehicleStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
    if (!widget.isVerified) {
      _controller.repeat(reverse: true);
    }
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

    final statusColor = widget.isVerified ? AppColors.success : AppColors.warning;
    final statusIcon = widget.isVerified
        ? Icons.verified_rounded
        : Icons.pending_rounded;
    final statusText = widget.isVerified
        ? 'Vehículo Verificado'
        : 'Pendiente de Verificación';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: widget.isVerified
                ? const AlwaysStoppedAnimation(1.0)
                : _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        if (widget.statusMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.statusMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.isVerified && widget.onVerify != null)
                    TextButton(
                      onPressed: widget.onVerify,
                      style: TextButton.styleFrom(
                        foregroundColor: statusColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Verificar'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

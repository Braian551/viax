import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../theme/app_colors.dart';

/// Card para que el cliente confirme que pagó en efectivo.
/// 
/// Muestra el monto y pide confirmación con botones claros.
/// Reproduce sonido de alerta para llamar la atención.
class ClientPaymentConfirmCard extends StatefulWidget {
  final double monto;
  final String metodoPago;
  final bool isDark;
  final ValueChanged<bool>? onPaymentConfirmed;
  final bool isLoading;

  const ClientPaymentConfirmCard({
    super.key,
    required this.monto,
    required this.metodoPago,
    required this.isDark,
    this.onPaymentConfirmed,
    this.isLoading = false,
  });

  @override
  State<ClientPaymentConfirmCard> createState() => _ClientPaymentConfirmCardState();
}

class _ClientPaymentConfirmCardState extends State<ClientPaymentConfirmCard>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasConfirmed = false;
  bool? _confirmedValue;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _playAlertSound();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _playAlertSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/request_notification.wav'));
    } catch (e) {
      // Si no hay archivo, usar vibración
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _confirmPayment(bool didPay) {
    HapticFeedback.mediumImpact();
    _audioPlayer.stop();
    setState(() {
      _hasConfirmed = true;
      _confirmedValue = didPay;
    });
    widget.onPaymentConfirmed?.call(didPay);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _hasConfirmed ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _hasConfirmed
                ? [
                    (_confirmedValue == true ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.15),
                    (_confirmedValue == true ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.05),
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hasConfirmed
                ? (_confirmedValue == true ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_hasConfirmed
                      ? (_confirmedValue == true ? AppColors.success : AppColors.error)
                      : AppColors.primary)
                  .withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _hasConfirmed
                    ? (_confirmedValue == true ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasConfirmed
                    ? (_confirmedValue == true
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded)
                    : Icons.payments_rounded,
                color: _hasConfirmed
                    ? (_confirmedValue == true ? AppColors.success : AppColors.error)
                    : AppColors.primary,
                size: 32,
              ),
            ),

            const SizedBox(height: 16),

            // Título
            Text(
              _hasConfirmed
                  ? (_confirmedValue == true ? 'Pago confirmado' : 'No pagaste')
                  : 'Confirma tu pago',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.grey[900],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Descripción
            if (!_hasConfirmed) ...[
              Text(
                '¿Pagaste el viaje en efectivo?',
                style: TextStyle(
                  color: widget.isDark ? Colors.white60 : Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            // Monto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    color: _hasConfirmed
                        ? (_confirmedValue == true ? AppColors.success : AppColors.error)
                        : AppColors.primary,
                    size: 28,
                  ),
                  Text(
                    widget.monto.toStringAsFixed(0),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.grey[900],
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.metodoPago,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Botones o mensaje de confirmación
            if (widget.isLoading)
              const CircularProgressIndicator()
            else if (_hasConfirmed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_confirmedValue == true ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _confirmedValue == true
                          ? Icons.check_circle
                          : Icons.info_outline,
                      color: _confirmedValue == true
                          ? AppColors.success
                          : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _confirmedValue == true
                          ? 'Esperando confirmación del conductor'
                          : 'Marcado como no pagado',
                      style: TextStyle(
                        color: _confirmedValue == true
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                children: [
                  // Botón NO
                  Expanded(
                    child: _buildOptionButton(
                      onTap: () => _confirmPayment(false),
                      icon: Icons.close_rounded,
                      label: 'No pagué',
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón SÍ
                  Expanded(
                    flex: 2,
                    child: _buildOptionButton(
                      onTap: () => _confirmPayment(true),
                      icon: Icons.check_rounded,
                      label: 'Sí, pagué',
                      color: AppColors.success,
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Advertencia
              Text(
                '⚠️ Marca la respuesta correcta. Si hay desacuerdo\nambas cuentas serán suspendidas.',
                style: TextStyle(
                  color: widget.isDark ? Colors.white38 : Colors.grey[500],
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isPrimary ? null : Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : color,
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

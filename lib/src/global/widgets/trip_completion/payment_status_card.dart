import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';

/// Estados de pago posibles.
enum PaymentStatus {
  pending,    // Pendiente de pago
  paid,       // Pagado
  cash,       // Efectivo (a recibir)
  confirmed,  // Confirmado por conductor
}

/// Card para mostrar y confirmar estado de pago.
/// 
/// Usado principalmente por el conductor para confirmar
/// si recibió el pago en efectivo.
class PaymentStatusCard extends StatefulWidget {
  final PaymentStatus status;
  final double monto;
  final String metodoPago;
  final bool isDark;
  final ValueChanged<bool>? onPaymentConfirmed;

  const PaymentStatusCard({
    super.key,
    required this.status,
    required this.monto,
    required this.metodoPago,
    required this.isDark,
    this.onPaymentConfirmed,
  });

  @override
  State<PaymentStatusCard> createState() => _PaymentStatusCardState();
}

class _PaymentStatusCardState extends State<PaymentStatusCard> {
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _isConfirmed = widget.status == PaymentStatus.confirmed ||
                   widget.status == PaymentStatus.paid;
  }

  Color get _statusColor {
    if (_isConfirmed || widget.status == PaymentStatus.paid) {
      return AppColors.success;
    }
    if (widget.status == PaymentStatus.cash) {
      return AppColors.warning;
    }
    return AppColors.error;
  }

  IconData get _statusIcon {
    if (_isConfirmed || widget.status == PaymentStatus.paid) {
      return Icons.check_circle_rounded;
    }
    if (widget.status == PaymentStatus.cash) {
      return Icons.money_rounded;
    }
    return Icons.pending_rounded;
  }

  String get _statusText {
    if (_isConfirmed) return 'Pago confirmado';
    if (widget.status == PaymentStatus.paid) return 'Pagado';
    if (widget.status == PaymentStatus.cash) return 'Pendiente de cobro';
    return 'Pendiente';
  }

  bool get _showConfirmButton {
    return widget.status == PaymentStatus.cash && 
           !_isConfirmed && 
           widget.onPaymentConfirmed != null;
  }

  void _confirmPayment() {
    HapticFeedback.mediumImpact();
    setState(() => _isConfirmed = true);
    widget.onPaymentConfirmed?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor.withValues(alpha: 0.15),
            _statusColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado del pago',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Monto y método
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDark 
                  ? Colors.black26 
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Monto
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto a cobrar',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${widget.monto.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.grey[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                // Método
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPaymentIcon(widget.metodoPago),
                        color: _statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.metodoPago,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Botón de confirmación
          if (_showConfirmButton) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmPayment,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirmar pago recibido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          
          // Mensaje de confirmado
          if (_isConfirmed && widget.status == PaymentStatus.cash) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text(
                  '¡Pago confirmado correctamente!',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String metodo) {
    final lower = metodo.toLowerCase();
    if (lower.contains('efectivo') || lower.contains('cash')) {
      return Icons.money_rounded;
    } else if (lower.contains('tarjeta') || lower.contains('card')) {
      return Icons.credit_card_rounded;
    } else if (lower.contains('nequi') || lower.contains('daviplata')) {
      return Icons.phone_android_rounded;
    }
    return Icons.payment_rounded;
  }
}

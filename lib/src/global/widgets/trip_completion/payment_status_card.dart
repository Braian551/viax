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
  final VoidCallback? onPaymentNotReceived;
  final bool isLoading;

  const PaymentStatusCard({
    super.key,
    required this.status,
    required this.monto,
    required this.metodoPago,
    required this.isDark,
    this.onPaymentConfirmed,
    this.onPaymentNotReceived,
    this.isLoading = false,
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
      return Icons.payments_rounded;
    }
    return Icons.pending_rounded;
  }

  String get _statusText {
    if (_isConfirmed) return 'Pago confirmado';
    if (widget.status == PaymentStatus.paid) return 'Pagado';
    if (widget.status == PaymentStatus.cash) return 'Confirma el cobro';
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

  void _reportNotReceived() {
    HapticFeedback.heavyImpact();
    widget.onPaymentNotReceived?.call();
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
          
          // Botones de confirmación
          if (_showConfirmButton) ...[
            const SizedBox(height: 20),
            
            // Loading state
            if (widget.isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else ...[
              // Botón principal: Confirmar pago recibido
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Confirmar pago recibido',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Botón secundario: No recibí el pago
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _reportNotReceived,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel_outlined, size: 20, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(
                        'No recibí el pago',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Advertencia sobre disputas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, 
                        color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Si reportas "No recibí", se verificará con el cliente y puede generar una disputa',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          
          // Mensaje de confirmado
          if (_isConfirmed && widget.status == PaymentStatus.cash) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_rounded, 
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '¡Pago confirmado!',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String metodo) {
    final lower = metodo.toLowerCase();
    if (lower.contains('efectivo') || lower.contains('cash')) {
      return Icons.payments_rounded;
    } else if (lower.contains('tarjeta') || lower.contains('card')) {
      return Icons.credit_card_rounded;
    } else if (lower.contains('nequi') || lower.contains('daviplata')) {
      return Icons.phone_android_rounded;
    }
    return Icons.payment_rounded;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../theme/app_colors.dart';
import '../../services/dispute_service.dart';

/// Overlay que bloquea la app cuando hay una disputa activa.
/// 
/// Se muestra en pantalla completa con sonido de alerta.
/// El usuario no puede cerrar este overlay hasta resolver la disputa.
class DisputeAlertOverlay extends StatefulWidget {
  final DisputaData disputa;
  final VoidCallback? onDisputeResolved;

  const DisputeAlertOverlay({
    super.key,
    required this.disputa,
    this.onDisputeResolved,
  });

  @override
  State<DisputeAlertOverlay> createState() => _DisputeAlertOverlayState();
}

class _DisputeAlertOverlayState extends State<DisputeAlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _playAlertSound();
    HapticFeedback.heavyImpact();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _playAlertSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/didi_notification.wav'));
    } catch (e) {
      // Si no hay archivo de sonido, usar vibración
      HapticFeedback.vibrate();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _resolveDispute() async {
    if (_isResolving) return;
    
    // Solo el conductor puede resolver la disputa
    if (!widget.disputa.soyConductor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo el conductor puede confirmar el pago recibido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isResolving = true);
    HapticFeedback.mediumImpact();
    
    final success = await DisputeService().resolveDispute(
      disputaId: widget.disputa.id,
      conductorId: widget.disputa.conductor.id,
    );

    if (success) {
      await _audioPlayer.stop();
      widget.onDisputeResolved?.call();
    } else {
      setState(() => _isResolving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al resolver disputa. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // No permitir cerrar con botón atrás
      child: Material(
        color: Colors.black.withValues(alpha: 0.95),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono de alerta animado
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.error,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppColors.error,
                      size: 60,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Título
                const Text(
                  '⚠️ DISPUTA DE PAGO',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Mensaje
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.disputa.mensaje,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _buildStatusRow(
                        icon: Icons.person_outline,
                        label: 'Cliente (${widget.disputa.cliente.nombre})',
                        status: widget.disputa.cliente.confirmaPago
                            ? 'Dice que SÍ pagó'
                            : 'Dice que NO pagó',
                        isPositive: widget.disputa.cliente.confirmaPago,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        icon: Icons.drive_eta_outlined,
                        label: 'Conductor (${widget.disputa.conductor.nombre})',
                        status: widget.disputa.conductor.confirmaPago
                            ? 'Dice que SÍ recibió'
                            : 'Dice que NO recibió',
                        isPositive: widget.disputa.conductor.confirmaPago,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Info del viaje
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route, color: Colors.white54, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.disputa.viaje.origen} → ${widget.disputa.viaje.destino}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Monto en disputa: \$${widget.disputa.viaje.precio.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Botón de resolución (solo conductor)
                if (widget.disputa.soyConductor) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isResolving ? null : _resolveDispute,
                      icon: _isResolving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isResolving
                            ? 'Resolviendo...'
                            : 'Confirmar que SÍ recibí el pago',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Al confirmar, la disputa se resolverá y ambas\ncuentas serán desbloqueadas.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  // Mensaje para el cliente
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: AppColors.warning),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esperando que el conductor confirme el pago recibido para desbloquear tu cuenta.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Contacto soporte
                TextButton.icon(
                  onPressed: () {
                    // TODO: Abrir chat de soporte
                  },
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Contactar soporte'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required String status,
    required bool isPositive,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPositive
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: isPositive ? AppColors.success : AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

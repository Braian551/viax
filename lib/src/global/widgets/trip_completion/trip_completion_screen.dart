import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../services/dispute_service.dart';
import 'star_rating_widget.dart';
import 'trip_summary_card.dart';
import 'payment_status_card.dart';
import 'client_payment_confirm_card.dart';
import '../../../features/user/presentation/widgets/trip_history/trip_conductor_avatar.dart';

/// Tipo de usuario que ve la pantalla.
enum TripCompletionUserType { cliente, conductor }

/// Datos necesarios para mostrar la pantalla de completación.
class TripCompletionData {
  final int solicitudId;
  final String origen;
  final String destino;
  final double distanciaKm;
  /// Duración en segundos (preferido para formato flexible)
  final int duracionSegundos;
  /// Duración en minutos (legacy, se usa si duracionSegundos = 0)
  final int duracionMinutos;
  final double precio;
  final String metodoPago;
  final String otroUsuarioNombre;
  final String? otroUsuarioFoto;
  final double? otroUsuarioCalificacion;

  const TripCompletionData({
    required this.solicitudId,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    this.duracionSegundos = 0,
    this.duracionMinutos = 0,
    required this.precio,
    required this.metodoPago,
    required this.otroUsuarioNombre,
    this.otroUsuarioFoto,
    this.otroUsuarioCalificacion,
  });
}

/// Pantalla de completación de viaje.
///
/// Reutilizable para conductor y cliente con diferentes configuraciones.
class TripCompletionScreen extends StatefulWidget {
  final TripCompletionUserType userType;
  final TripCompletionData tripData;
  final int miUsuarioId;
  final int otroUsuarioId;
  /// Callback para enviar la calificación.
  /// Retorna un Map con 'success' (bool) y opcionalmente 'updated' (bool).
  /// Si 'updated' es true, significa que se actualizó una calificación existente.
  final Future<Map<String, dynamic>> Function(int rating, String? comentario) onSubmitRating;
  final Future<bool> Function(bool received)? onConfirmPayment;
  final VoidCallback onComplete;

  const TripCompletionScreen({
    super.key,
    required this.userType,
    required this.tripData,
    required this.miUsuarioId,
    required this.otroUsuarioId,
    required this.onSubmitRating,
    this.onConfirmPayment,
    required this.onComplete,
  });

  @override
  State<TripCompletionScreen> createState() => _TripCompletionScreenState();
}

class _TripCompletionScreenState extends State<TripCompletionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _selectedRating = 0;
  String _comentario = '';
  bool _paymentConfirmed = false; // Conductor dice que SÍ recibió
  bool _paymentReported = false; // Conductor ya reportó (sí o no)
  bool _clientPaymentConfirmed = false;
  bool _isSubmitting = false;
  bool _ratingSubmitted = false;
  bool _ratingWasUpdated = false; // Nueva: indica si se actualizó una calificación existente
  bool _isReportingPayment = false;
  bool _hasDispute = false;

  bool get _isConductor => widget.userType == TripCompletionUserType.conductor;
  bool get _isCliente => widget.userType == TripCompletionUserType.cliente;
  // Solo efectivo es soportado
  bool get _isEfectivo => true;

  bool get _canComplete {
    // SIMPLIFICACIÓN: Siempre permitir completar, ignorando estados de pago
    return true;
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // SIMPLIFICACIÓN: Desactivar verificación de disputas
    // _checkActiveDispute(); 
  }

  /// Verifica si el usuario ya tiene una disputa activa al abrir la pantalla
  Future<void> _checkActiveDispute() async {
    // SIMPLIFICACIÓN: Lógica de disputas desactivada
    return;
    /*
    try {
      final result = await DisputeService().checkDisputeStatus(
        widget.miUsuarioId,
      );

      if (result.tieneDisputa && result.disputa != null && mounted) {
        debugPrint('⚠️ ¡Disputa activa encontrada! ID: ${result.disputa!.id}');
        setState(() {
          _hasDispute = true;
        });

        // Mostrar overlay de disputa después de que el widget esté construido
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showDisputeOverlay(result.disputa!.id);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error verificando disputa: $e');
    }
    */
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await widget.onSubmitRating(
        _selectedRating,
        _comentario.isNotEmpty ? _comentario : null,
      );

      final success = result['success'] == true;
      final wasUpdated = result['updated'] == true;

      if (success && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _ratingSubmitted = true;
          _ratingWasUpdated = wasUpdated;
        });

        // Esperar un momento y luego completar
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) widget.onComplete();
      } else if (!success && mounted) {
        // Mostrar error del servidor
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al enviar calificación'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al enviar calificación'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _skipRating() {
    HapticFeedback.lightImpact();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  statusBarHeight > 40 ? 0 : 20,
                  20,
                  20,
                ),
                child: Column(
                  children: [
                    // Header con éxito
                    _buildSuccessHeader(isDark),

                    const SizedBox(height: 24),

                    // SIMPLIFICACIÓN: Valor grande para Conductor (Efectivo)
                    if (_isConductor && _isEfectivo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'TOTAL A COBRAR',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${_formatCurrency(_getFinalPrice())}',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Efectivo',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Resumen del viaje
                    TripSummaryCard(
                      origen: widget.tripData.origen,
                      destino: widget.tripData.destino,
                      distanciaKm: widget.tripData.distanciaKm,
                      duracionSegundos: widget.tripData.duracionSegundos,
                      duracionMinutos: widget.tripData.duracionMinutos,
                      precio: _getFinalPrice(), // Usar precio redondeado si aplica
                      metodoPago: widget.tripData.metodoPago,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 20),

                    // SIMPLIFICACIÓN: Mensaje informativo para Cliente
                    if (_isCliente && _isEfectivo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.blue.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: isDark ? Colors.white70 : Colors.blue,
                                size: 28,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Pago realizado directamente al conductor',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Este viaje no requiere confirmación en la app',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Sección de calificación
                    _buildRatingSection(isDark),

                    const SizedBox(height: 24),

                    // Botones de acción
                    _buildActionButtons(isDark),

                    const SizedBox(height: 16),

                    // Botón "Ir al inicio" siempre visible
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onComplete();
                        },
                        icon: const Icon(Icons.home_rounded),
                        label: const Text(
                          'Ir al inicio',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white70
                              : Colors.grey[700],
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader(bool isDark) {
    return Column(
      children: [
        // Ícono de éxito animado
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success,
                  AppColors.success.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          '¡Viaje completado!',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.grey[900],
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _isConductor
              ? 'Has llegado al destino con tu pasajero'
              : 'Has llegado a tu destino',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRatingSection(bool isDark) {
    final targetName = widget.tripData.otroUsuarioNombre;
    final targetLabel = _isConductor ? 'al pasajero' : 'al conductor';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Avatar y nombre
          Row(
            children: [
              // Avatar
              // Usar TripConductorAvatar si es el cliente viendo al conductor,
              // o si queremos soportar imágenes de R2 para ambos.
              // Dado que el componente se llama TripConductorAvatar, lo usaremos principalmente
              // cuando mostramos al conductor, pero su lógica de URL es útil para todos.
              TripConductorAvatar(
                photoUrl: widget.tripData.otroUsuarioFoto,
                conductorName: targetName,
                radius: 25,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetName,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.tripData.otroUsuarioCalificacion != null)
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.tripData.otroUsuarioCalificacion!
                                .toStringAsFixed(1),
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Texto
          Text(
            '¿Cómo fue tu experiencia con $targetLabel?',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Estrellas
          if (_ratingSubmitted)
            _buildRatingSubmittedMessage(isDark)
          else
            StarRatingWidget(
              initialRating: _selectedRating,
              onRatingChanged: (rating) {
                setState(() => _selectedRating = rating);
              },
              starSize: 44,
              spacing: 6,
            ),

          // Campo de comentario (opcional)
          if (_selectedRating > 0 && !_ratingSubmitted) ...[
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) => _comentario = value,
              maxLines: 2,
              maxLength: 200,
              style: TextStyle(color: isDark ? Colors.white : Colors.grey[900]),
              decoration: InputDecoration(
                hintText: 'Comentario opcional...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
                counterStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSubmittedMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _ratingWasUpdated ? Icons.update_rounded : Icons.check_circle_rounded, 
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            _ratingWasUpdated 
                ? '¡Calificación actualizada!' 
                : '¡Gracias por tu calificación!',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Column(
      children: [
        // Botón principal - solo mostrar si NO se ha enviado la calificación
        if (!_ratingSubmitted)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _canComplete && !_isSubmitting
                  ? (_selectedRating > 0 ? _submitRating : _skipRating)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedRating > 0
                    ? AppColors.primary
                    : (isDark ? Colors.white12 : Colors.grey[300]),
                foregroundColor: _selectedRating > 0
                    ? Colors.black
                    : (isDark ? Colors.white54 : Colors.grey[600]),
                disabledBackgroundColor: isDark
                    ? Colors.white12
                    : Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: _selectedRating > 0 ? 4 : 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedRating > 0
                              ? Icons.send_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedRating > 0
                              ? 'Enviar calificación'
                              : (_isConductor ? 'Finalizar viaje' : 'Continuar sin calificar'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

        // Mensaje de pago pendiente
        if (_isConductor && _isEfectivo && !_paymentReported)
          const SizedBox.shrink(),
      ],
    );
  }

  /// Maneja cuando el CONDUCTOR confirma que SÍ recibió el pago.
  Future<void> _handleConductorPaymentConfirm(bool confirmed) async {
    setState(() => _isReportingPayment = true);

    try {
      final result = await DisputeService().reportPaymentStatus(
        solicitudId: widget.tripData.solicitudId,
        usuarioId: widget.miUsuarioId,
        tipoUsuario: 'conductor',
        confirmaPago: confirmed,
      );

      if (result.success) {
        setState(() {
          _paymentReported = true; // Ya se reportó el estado
          _paymentConfirmed = confirmed; // True si dijo que sí recibió
          _hasDispute = result.hayDisputa;
        });

        widget.onConfirmPayment?.call(confirmed);

        if (result.hayDisputa) {
          // Mostrar diálogo de disputa que bloquea la app
          _showDisputeOverlay(result.disputaId);
        } else if (confirmed) {
          _showSuccessSnackbar('Pago confirmado exitosamente');
        } else {
          // Conductor dijo "no recibí" pero aún no hay disputa (cliente no ha confirmado)
          // Mostrar un diálogo explicativo pero permitir continuar
          _showPaymentNotReceivedDialog();
        }
      } else {
        _showErrorSnackbar(result.mensaje);
      }
    } catch (e) {
      _showErrorSnackbar('Error al reportar pago: $e');
    } finally {
      setState(() => _isReportingPayment = false);
    }
  }

  /// Maneja cuando el CONDUCTOR dice que NO recibió el pago.
  Future<void> _handleConductorPaymentNotReceived() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¿No recibiste el pago?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Si el cliente afirma que sí pagó, se creará una disputa y ambas cuentas serán suspendidas temporalmente.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.gavel_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠️ IMPORTANTE: Solo marca "No" si realmente no recibiste el dinero.',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar: No recibí'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _handleConductorPaymentConfirm(false);
    }
  }

  /// Maneja cuando el CLIENTE confirma si pagó o no.
  Future<void> _handleClientPaymentConfirm(bool didPay) async {
    setState(() => _isReportingPayment = true);

    try {
      final result = await DisputeService().reportPaymentStatus(
        solicitudId: widget.tripData.solicitudId,
        usuarioId: widget.miUsuarioId,
        tipoUsuario: 'cliente',
        confirmaPago: didPay,
      );

      if (result.success) {
        setState(() {
          _clientPaymentConfirmed = true;
          _hasDispute = result.hayDisputa;
        });

        if (result.hayDisputa) {
          _showDisputeCreatedDialog();
        } else if (didPay) {
          _showSuccessSnackbar('Pago confirmado. Esperando al conductor.');
        }
      } else {
        _showErrorSnackbar(result.mensaje);
      }
    } catch (e) {
      _showErrorSnackbar('Error al reportar pago: $e');
    } finally {
      setState(() => _isReportingPayment = false);
    }
  }

  void _showDisputeCreatedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.gavel_rounded, color: AppColors.error, size: 32),
            const SizedBox(width: 12),
            const Text('Disputa creada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hay un desacuerdo sobre el pago de este viaje.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ambas cuentas han sido suspendidas hasta que se resuelva la disputa.',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Salir de la pantalla de completación
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra diálogo cuando conductor dice que NO recibió el pago pero aún no hay disputa
  void _showPaymentNotReceivedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Reporte enviado', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Has reportado que NO recibiste el pago.',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.grey[900],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Si el cliente confirma que SÍ pagó, se creará una disputa y ambas cuentas serán suspendidas hasta resolverlo.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Puedes continuar con tu actividad normalmente.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Entendido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra overlay de disputa con opción para que conductor resuelva
  void _showDisputeOverlay(int? disputaId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.error.withValues(alpha: 0.95),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícono animado
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      '⚠️ CUENTA SUSPENDIDA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Se ha creado una disputa por desacuerdo en el pago.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Card con estados
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.white70),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Cliente dice:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'SÍ PAGUÉ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_car,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Tú dijiste:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'NO RECIBÍ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botón para resolver (conductor)
                    if (_isConductor) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              _resolveDispute(dialogContext, disputaId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Confirmo que recibí el pago',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Botón ir al inicio (para ambos)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          widget.onComplete(); // Ir al inicio
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home),
                            SizedBox(width: 8),
                            Text(
                              'Ir al inicio',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Resuelve la disputa (conductor confirma que sí recibió)
  Future<void> _resolveDispute(
    BuildContext dialogContext,
    int? disputaId,
  ) async {
    if (disputaId == null) return;

    try {
      final success = await DisputeService().resolveDispute(
        disputaId: disputaId,
        conductorId: widget.miUsuarioId,
      );

      if (success) {
        Navigator.pop(dialogContext);
        _showSuccessSnackbar('¡Disputa resuelta! Ambas cuentas desbloqueadas.');

        setState(() {
          _hasDispute = false;
          _paymentConfirmed = true;
        });
      } else {
        _showErrorSnackbar('Error al resolver disputa');
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Calcula el precio final aplicando redondeo si es efectivo
  double _getFinalPrice() {
    if (_isEfectivo) {
      return _roundPrice(widget.tripData.precio);
    }
    return widget.tripData.precio;
  }

  /// Redondea el precio al múltiplo de 100 más cercano
  double _roundPrice(double price) {
    return (price / 100).round() * 100.0;
  }

  /// Formatea la moneda con separadores de miles
  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }
}

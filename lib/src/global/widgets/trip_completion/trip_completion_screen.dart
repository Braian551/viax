import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import 'star_rating_widget.dart';
import 'trip_summary_card.dart';
import 'payment_status_card.dart';

/// Tipo de usuario que ve la pantalla.
enum TripCompletionUserType {
  cliente,
  conductor,
}

/// Datos necesarios para mostrar la pantalla de completación.
class TripCompletionData {
  final int solicitudId;
  final String origen;
  final String destino;
  final double distanciaKm;
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
    required this.duracionMinutos,
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
  final Future<bool> Function(int rating, String? comentario) onSubmitRating;
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
  bool _paymentConfirmed = false;
  bool _isSubmitting = false;
  bool _ratingSubmitted = false;

  bool get _isConductor => widget.userType == TripCompletionUserType.conductor;
  bool get _isEfectivo => widget.tripData.metodoPago.toLowerCase().contains('efectivo');
  
  bool get _canComplete {
    if (_isConductor && _isEfectivo && !_paymentConfirmed) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    
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
      final success = await widget.onSubmitRating(
        _selectedRating,
        _comentario.isNotEmpty ? _comentario : null,
      );
      
      if (success && mounted) {
        HapticFeedback.mediumImpact();
        setState(() => _ratingSubmitted = true);
        
        // Esperar un momento y luego completar
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) widget.onComplete();
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
                padding: EdgeInsets.fromLTRB(20, statusBarHeight > 40 ? 0 : 20, 20, 20),
                child: Column(
                  children: [
                    // Header con éxito
                    _buildSuccessHeader(isDark),
                    
                    const SizedBox(height: 24),
                    
                    // Resumen del viaje
                    TripSummaryCard(
                      origen: widget.tripData.origen,
                      destino: widget.tripData.destino,
                      distanciaKm: widget.tripData.distanciaKm,
                      duracionMinutos: widget.tripData.duracionMinutos,
                      precio: widget.tripData.precio,
                      metodoPago: widget.tripData.metodoPago,
                      isDark: isDark,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Card de pago (solo conductor con efectivo)
                    if (_isConductor && _isEfectivo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: PaymentStatusCard(
                          status: _paymentConfirmed 
                              ? PaymentStatus.confirmed 
                              : PaymentStatus.cash,
                          monto: widget.tripData.precio,
                          metodoPago: widget.tripData.metodoPago,
                          isDark: isDark,
                          onPaymentConfirmed: (confirmed) {
                            setState(() => _paymentConfirmed = confirmed);
                            widget.onConfirmPayment?.call(confirmed);
                          },
                        ),
                      ),
                    
                    // Sección de calificación
                    _buildRatingSection(isDark),
                    
                    const SizedBox(height: 24),
                    
                    // Botones de acción
                    _buildActionButtons(isDark),
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
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)],
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
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          // Avatar y nombre
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: widget.tripData.otroUsuarioFoto != null
                    ? NetworkImage(widget.tripData.otroUsuarioFoto!)
                    : null,
                child: widget.tripData.otroUsuarioFoto == null
                    ? Text(
                        targetName.isNotEmpty 
                            ? targetName[0].toUpperCase() 
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
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
                          Icon(Icons.star_rounded, 
                              color: Colors.amber, size: 16),
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
              style: TextStyle(
                color: isDark ? Colors.white : Colors.grey[900],
              ),
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
          Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 8),
          Text(
            '¡Gracias por tu calificación!',
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
        // Botón principal
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
              disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey[200],
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
                            : 'Continuar sin calificar',
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
        if (_isConductor && _isEfectivo && !_paymentConfirmed) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, 
                  color: AppColors.warning, size: 16),
              const SizedBox(width: 6),
              Text(
                'Confirma el pago para continuar',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

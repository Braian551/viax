import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

/// Estado de un botón de acción con reintentos
enum ActionButtonState {
  idle,
  loading,
  success,
  error,
  retrying,
}

/// Botón de acción con estado de carga y reintentos automáticos
/// 
/// Características:
/// - Indicador visual de carga mientras procesa
/// - Animación de éxito/error
/// - Reintentos automáticos con feedback visual
/// - Prevención de doble tap
/// - Haptic feedback
class ResilientActionButton extends StatefulWidget {
  /// Texto del botón en estado idle
  final String label;
  
  /// Icono del botón
  final IconData icon;
  
  /// Color de fondo
  final Color backgroundColor;
  
  /// Acción a ejecutar (debe retornar éxito o error)
  final Future<bool> Function() onAction;
  
  /// Callback cuando la acción fue exitosa
  final VoidCallback? onSuccess;
  
  /// Callback cuando la acción falló
  final void Function(String error)? onError;
  
  /// Número máximo de reintentos automáticos
  final int maxRetries;
  
  /// Delay entre reintentos (se incrementa exponencialmente)
  final Duration retryDelay;
  
  /// Mensaje mostrado durante carga
  final String? loadingMessage;
  
  /// Mensaje mostrado durante reintento
  final String? retryMessage;
  
  /// Permitir reintentos manuales después de error
  final bool allowManualRetry;
  
  /// Altura del botón
  final double height;
  
  /// Borde redondeado
  final double borderRadius;

  const ResilientActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onAction,
    this.onSuccess,
    this.onError,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.loadingMessage,
    this.retryMessage,
    this.allowManualRetry = true,
    this.height = 54,
    this.borderRadius = 14,
  });

  @override
  State<ResilientActionButton> createState() => _ResilientActionButtonState();
}

class _ResilientActionButtonState extends State<ResilientActionButton>
    with SingleTickerProviderStateMixin {
  ActionButtonState _state = ActionButtonState.idle;
  int _currentRetry = 0;
  String? _errorMessage;
  Timer? _retryTimer;
  int _retryCountdown = 0;
  
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_state == ActionButtonState.loading || 
        _state == ActionButtonState.retrying) {
      return;
    }
    
    HapticFeedback.mediumImpact();
    await _executeAction();
  }

  Future<void> _executeAction() async {
    setState(() {
      _state = _currentRetry > 0 
        ? ActionButtonState.retrying 
        : ActionButtonState.loading;
      _errorMessage = null;
    });

    try {
      final success = await widget.onAction();
      
      if (success) {
        _handleSuccess();
      } else {
        _handleError('La operación no se completó');
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleSuccess() {
    if (!mounted) return;
    
    HapticFeedback.heavyImpact();
    setState(() {
      _state = ActionButtonState.success;
      _currentRetry = 0;
    });
    
    _animController.forward().then((_) {
      if (mounted) {
        _animController.reverse();
        widget.onSuccess?.call();
      }
    });
  }

  void _handleError(String error) {
    if (!mounted) return;
    
    _currentRetry++;
    
    if (_currentRetry < widget.maxRetries) {
      // Programar reintento automático
      _scheduleRetry();
    } else {
      // Máximo de reintentos alcanzado
      HapticFeedback.heavyImpact();
      setState(() {
        _state = ActionButtonState.error;
        _errorMessage = error;
      });
      
      // Animar shake
      _animController.forward().then((_) {
        if (mounted) _animController.reverse();
      });
      
      widget.onError?.call(error);
    }
  }

  void _scheduleRetry() {
    final delay = widget.retryDelay * (1 << (_currentRetry - 1)); // Exponential backoff
    _retryCountdown = delay.inSeconds;
    
    setState(() {
      _state = ActionButtonState.retrying;
    });
    
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _retryCountdown--;
      });
      
      if (_retryCountdown <= 0) {
        timer.cancel();
        _executeAction();
      }
    });
  }

  void _resetState() {
    _retryTimer?.cancel();
    setState(() {
      _state = ActionButtonState.idle;
      _currentRetry = 0;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _state == ActionButtonState.error 
              ? _shakeAnimation.value * (_animController.value < 0.5 ? 1 : -1)
              : 0,
            0,
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: _state == ActionButtonState.loading || 
                    _state == ActionButtonState.retrying
            ? null
            : (_state == ActionButtonState.error && widget.allowManualRetry
                ? () {
                    _currentRetry = 0;
                    _handleTap();
                  }
                : _handleTap),
          style: ElevatedButton.styleFrom(
            backgroundColor: _getBackgroundColor(),
            foregroundColor: Colors.white,
            disabledBackgroundColor: widget.backgroundColor.withValues(alpha: 0.7),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            elevation: _state == ActionButtonState.loading ? 2 : 4,
          ),
          child: _buildContent(),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (_state) {
      case ActionButtonState.success:
        return AppColors.success;
      case ActionButtonState.error:
        return AppColors.error;
      case ActionButtonState.retrying:
        return AppColors.warning;
      default:
        return widget.backgroundColor;
    }
  }

  Widget _buildContent() {
    switch (_state) {
      case ActionButtonState.loading:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            if (widget.loadingMessage != null) ...[
              const SizedBox(width: 12),
              Text(
                widget.loadingMessage!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
        
      case ActionButtonState.retrying:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.retryMessage ?? 'Reintentando en ${_retryCountdown}s...',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
        
      case ActionButtonState.success:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              '¡Listo!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
        
      case ActionButtonState.error:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.allowManualRetry ? 'Reintentar' : 'Error',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
        
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
    }
  }
}

/// Overlay de sincronización para mostrar estado de operaciones en segundo plano
class SyncStatusOverlay extends StatelessWidget {
  final bool isVisible;
  final String message;
  final int pendingCount;
  final VoidCallback? onRetry;

  const SyncStatusOverlay({
    super.key,
    this.isVisible = false,
    this.message = 'Sincronizando...',
    this.pendingCount = 0,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (pendingCount > 0)
                      Text(
                        '$pendingCount operación${pendingCount > 1 ? 'es' : ''} pendiente${pendingCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (onRetry != null)
                IconButton(
                  icon: Icon(Icons.refresh, size: 20, color: AppColors.primary),
                  onPressed: onRetry,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

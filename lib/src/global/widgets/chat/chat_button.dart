import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../services/chat_service.dart';

/// Botón de chat con indicador de mensajes no leídos
/// 
/// Widget reutilizable que muestra un botón de chat con badge
/// para indicar mensajes no leídos. Usado en pantallas de viaje.
class ChatButton extends StatefulWidget {
  final int solicitudId;
  final int miUsuarioId;
  final VoidCallback onPressed;
  final bool isDark;
  final double? size;
  final Color? backgroundColor;
  final Color? iconColor;

  const ChatButton({
    super.key,
    required this.solicitudId,
    required this.miUsuarioId,
    required this.onPressed,
    required this.isDark,
    this.size,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  State<ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<ChatButton> with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  StreamSubscription<int>? _unreadSubscription;
  Timer? _pollTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animación de pulso para el badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Suscribirse al stream de no leídos
    _unreadSubscription = ChatService.unreadCountStream.listen((count) {
      if (mounted) {
        setState(() => _unreadCount = count);
        if (count > 0) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      }
    });
    
    // También hacer polling directo si no hay stream activo
    _startUnreadPolling();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startUnreadPolling() {
    // Carga inicial
    _loadUnreadCount();
    
    // Polling cada 10 segundos
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await ChatService.getUnreadCount(
        solicitudId: widget.solicitudId,
        usuarioId: widget.miUsuarioId,
      );
      if (mounted && count != _unreadCount) {
        setState(() => _unreadCount = count);
        if (count > 0 && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (count == 0) {
          _pulseController.stop();
        }
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 48.0;
    final bgColor = widget.backgroundColor ??
        (widget.isDark ? AppColors.darkCard : Colors.white);
    final iconClr = widget.iconColor ??
        (widget.isDark ? Colors.white : AppColors.lightTextPrimary);

    return Stack(
      children: [
        // Botón principal
        Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(size / 2),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.chat_bubble_rounded,
                color: iconClr,
                size: size * 0.5,
              ),
            ),
          ),
        ),
        
        // Badge de no leídos
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Center(
                  child: Text(
                    _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

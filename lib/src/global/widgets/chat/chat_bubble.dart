import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../services/chat_service.dart';

/// Burbuja de mensaje de chat
/// 
/// Widget reutilizable para mostrar un mensaje en el chat.
/// Soporta mensajes propios (derecha) y del otro usuario (izquierda).
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool esMio;
  final bool showTime;
  final bool showAvatar;
  final String? avatarUrl;
  final String? avatarInitial;

  const ChatBubble({
    super.key,
    required this.message,
    required this.esMio,
    this.showTime = true,
    this.showAvatar = true,
    this.avatarUrl,
    this.avatarInitial,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar del otro usuario (solo a la izquierda)
          if (!esMio && showAvatar) ...[
            _buildAvatar(isDark),
            const SizedBox(width: 8),
          ],
          
          // Contenedor de mensaje
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: esMio
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCard : Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(esMio ? 18 : 4),
                  bottomRight: Radius.circular(esMio ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contenido del mensaje
                  _buildMessageContent(isDark),
                  
                  // Hora y estado de lectura
                  if (showTime)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.fechaCreacion),
                            style: TextStyle(
                              fontSize: 11,
                              color: esMio
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            ),
                          ),
                          if (esMio) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.leido ? Icons.done_all : Icons.done,
                              size: 14,
                              color: message.leido
                                  ? Colors.lightBlueAccent
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Espacio para balance visual cuando es mensaje propio
          if (esMio && showAvatar) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade300,
      child: Text(
        avatarInitial ?? message.tipoRemitente[0].toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _buildMessageContent(bool isDark) {
    final textColor = esMio
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    
    switch (message.tipoMensaje) {
      case 'ubicacion':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: textColor, size: 18),
            const SizedBox(width: 6),
            Text(
              message.mensaje,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ],
        );
        
      case 'sistema':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: textColor, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message.mensaje,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        );
        
      default: // texto
        return Text(
          message.mensaje,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.3,
          ),
        );
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

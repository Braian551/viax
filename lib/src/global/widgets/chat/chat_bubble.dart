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

          // Contenedor de mensaje que se ajusta al contenido (IntrinsicWidth) con un maxWidth
          Align(
            alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  child: _buildMessageContent(isDark),
                ),
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

  Widget _buildInlineMeta(bool isDark) {
    // Inline metadata row: time (and optional check) shown inside bubble
    final timeColor = esMio
        ? Colors.white.withOpacity(0.95) // más visible sobre burbuja azul
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    final iconColor = esMio
        ? (message.leido ? Colors.white : Colors.white70) // check más blanco para mensajes propios
        : (message.leido ? Colors.lightBlueAccent : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary));

    final timeStyle = TextStyle(fontSize: 11, color: timeColor, fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatTime(message.fechaCreacion), style: timeStyle),
          if (esMio) ...[
            const SizedBox(width: 6),
            Icon(
              message.leido ? Icons.done_all : Icons.done,
              size: 14,
              color: iconColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(bool isDark) {
    final textColor = esMio
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    // Meta colors and widget
    final timeColor = esMio
        ? Colors.white.withOpacity(0.95)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    final iconColor = esMio
        ? (message.leido ? Colors.white : Colors.white70)
        : (message.leido ? Colors.lightBlueAccent : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary));

    Widget metaRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatTime(message.fechaCreacion), style: TextStyle(fontSize: 10, color: timeColor)) ,
          if (esMio) ...[
            const SizedBox(width: 4),
            Icon(message.leido ? Icons.done_all : Icons.done, size: 13, color: iconColor),
          ],
        ],
      );
    }

    switch (message.tipoMensaje) {
      case 'ubicacion':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: textColor, size: 16),
                const SizedBox(width: 6),
                Flexible(child: Text(message.mensaje, style: TextStyle(color: textColor, fontSize: 13))),
              ],
            ),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: metaRow()),
          ],
        );

      case 'sistema':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: textColor, size: 14),
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
            ),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: metaRow()),
          ],
        );

      default: // texto
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.mensaje,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.18),
            ),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: metaRow()),
          ],
        );
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

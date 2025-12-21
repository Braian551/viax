import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../services/chat_service.dart';
import 'chat_bubble.dart';
import 'chat_input_field.dart';
import 'quick_messages.dart';

/// Pantalla completa de chat reutilizable
/// 
/// Widget que muestra una conversación completa con:
/// - Lista de mensajes con scroll automático
/// - Campo de entrada para nuevos mensajes
/// - Actualización en tiempo real
/// - Soporte para modo claro/oscuro
class ChatScreen extends StatefulWidget {
  final int solicitudId;
  final int miUsuarioId;
  final int otroUsuarioId;
  final String miTipo; // 'cliente' o 'conductor'
  final String otroNombre;
  final String? otroFoto;
  final String? otroSubtitle; // Ej: "Conductor de Toyota Yaris"
  final VoidCallback? onClose;

  const ChatScreen({
    super.key,
    required this.solicitudId,
    required this.miUsuarioId,
    required this.otroUsuarioId,
    required this.miTipo,
    required this.otroNombre,
    this.otroFoto,
    this.otroSubtitle,
    this.onClose,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    
    // Iniciar polling
    ChatService.startPolling(
      solicitudId: widget.solicitudId,
      usuarioId: widget.miUsuarioId,
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    ChatService.stopPolling();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _subscribeToMessages() {
    _messagesSubscription = ChatService.messagesStream.listen((newMessages) {
      if (mounted) {
        setState(() {
          // Agregar solo mensajes nuevos que no tengamos
          for (final msg in newMessages) {
            if (!_messages.any((m) => m.id == msg.id)) {
              _messages.add(msg);
            }
          }
          // Ordenar por fecha
          _messages.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await ChatService.getAllMessages(
        solicitudId: widget.solicitudId,
        usuarioId: widget.miUsuarioId,
      );
      
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // Scroll al final después de cargar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading messages: $e');
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      final position = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    }
  }

  Future<void> _handleSend(String text) async {
    if (_isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      final message = await ChatService.sendMessage(
        solicitudId: widget.solicitudId,
        remitenteId: widget.miUsuarioId,
        destinatarioId: widget.otroUsuarioId,
        mensaje: text,
        tipoRemitente: widget.miTipo,
      );
      
      if (message != null && mounted) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildMessagesList(isDark),
          ),
          
          // Mensajes rápidos predeterminados
          QuickMessagesBar(
            userType: widget.miTipo == 'conductor' 
                ? ChatUserType.conductor 
                : ChatUserType.cliente,
            onMessageSelected: _handleSend,
            isDark: isDark,
          ),
          
          // Campo de entrada
          ChatInputField(
            onSend: _handleSend,
            enabled: !_isSending,
            focusNode: _inputFocusNode,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDark ? Colors.white : Colors.black,
        ),
        onPressed: widget.onClose ?? () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: widget.otroFoto != null && widget.otroFoto!.isNotEmpty
                ? NetworkImage(widget.otroFoto!)
                : null,
            child: widget.otroFoto == null || widget.otroFoto!.isEmpty
                ? Text(
                    widget.otroNombre.isNotEmpty ? widget.otroNombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Nombre y subtítulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otroNombre,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.otroSubtitle != null)
                  Text(
                    widget.otroSubtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Botón de llamada
        IconButton(
          icon: Icon(
            Icons.phone_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            // TODO: Implementar llamada
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Llamando...')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Inicia la conversación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Envía un mensaje para comunicarte con ${widget.otroNombre}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final esMio = message.esMio(widget.miUsuarioId);
        
        // Mostrar separador de fecha si es necesario
        Widget? dateSeparator;
        if (index == 0 || !_isSameDay(_messages[index - 1].fechaCreacion, message.fechaCreacion)) {
          dateSeparator = _buildDateSeparator(message.fechaCreacion, isDark);
        }
        
        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            ChatBubble(
              message: message,
              esMio: esMio,
              showAvatar: !esMio,
              avatarUrl: esMio ? null : widget.otroFoto,
              avatarInitial: esMio ? null : widget.otroNombre[0],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Hoy';
    } else if (messageDate == yesterday) {
      return 'Ayer';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

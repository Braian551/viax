import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/features/support/services/support_service.dart';

/// Pantalla de chat para un ticket de soporte
class TicketChatScreen extends StatefulWidget {
  final int ticketId;
  final int? userId;
  final int? agentId;

  const TicketChatScreen({
    super.key,
    required this.ticketId,
    this.userId,
    this.agentId,
  });

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  
  Map<String, dynamic>? _ticket;
  List<TicketMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  bool get _isAgentMode => widget.agentId != null;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadMessages(showLoader: false);
    });
  }

  Future<void> _loadMessages({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    final result = await SupportService.getTicketMessages(
      ticketId: widget.ticketId,
      userId: _isAgentMode ? null : widget.userId,
      agentId: _isAgentMode ? widget.agentId : null,
    );

    if (mounted && result != null) {
      final nextMessages = result['mensajes'] as List<TicketMessage>;
      final previousLastId = _messages.isNotEmpty ? _messages.last.id : 0;
      final nextLastId = nextMessages.isNotEmpty ? nextMessages.last.id : 0;
      final hasNewMessages = nextLastId != previousLastId || nextMessages.length != _messages.length;

      setState(() {
        _ticket = result['ticket'];
        _messages = nextMessages;
        _isLoading = false;
      });
      if (showLoader || hasNewMessages) {
        _scrollToBottom();
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final message = await SupportService.sendMessage(
      ticketId: widget.ticketId,
      userId: _isAgentMode ? null : widget.userId,
      agentId: _isAgentMode ? widget.agentId : null,
      message: text,
    );

    if (mounted) {
      setState(() => _isSending = false);
      
      if (message != null) {
        await _loadMessages(showLoader: false);
      } else {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al enviar mensaje'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClosed = _ticket?['estado'] == 'cerrado';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ticket?['numero_ticket'] ?? 'Ticket',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (_ticket != null)
              Text(
                _isAgentMode
                    ? '${_ticket!['asunto'] ?? ''} • Modo agente'
                    : (_ticket!['asunto'] ?? ''),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mensajes
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessage(message, isDark);
                          },
                        ),
                ),
                
                // Input de mensaje
                if (!isClosed)
                  _buildMessageInput(isDark)
                else
                  _buildClosedBanner(isDark),
              ],
            ),
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
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin mensajes aún',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Envía un mensaje para iniciar la conversación',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(TicketMessage message, bool isDark) {
    final isAgent = message.esAgente;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isAgent ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAgent) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.support_agent_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAgent
                    ? (isDark ? AppColors.darkCard : Colors.white)
                    : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isAgent ? Radius.zero : const Radius.circular(16),
                  bottomRight: isAgent ? const Radius.circular(16) : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAgent && message.remitenteNombre != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.remitenteNombre!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  Text(
                    message.mensaje,
                    style: TextStyle(
                      fontSize: 14,
                      color: isAgent
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isAgent
                          ? (isDark ? Colors.white38 : Colors.black38)
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (!isAgent) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : Colors.grey.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.darkSurface : Colors.grey.withValues(alpha: 0.1),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 18,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            const SizedBox(width: 8),
            Text(
              'Este ticket ha sido cerrado',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final utc = date.isUtc ? date : date.toUtc();
    final bogotaDate = utc.subtract(const Duration(hours: 5));
    final nowBogota = DateTime.now().toUtc().subtract(const Duration(hours: 5));

    final sameDay =
        bogotaDate.year == nowBogota.year &&
        bogotaDate.month == nowBogota.month &&
        bogotaDate.day == nowBogota.day;

    final pattern = sameDay ? 'hh:mm a' : 'dd/MM hh:mm a';
    final formatted = DateFormat(pattern, 'es_CO').format(bogotaDate);
    return formatted
        .replaceAll('a. m.', 'AM')
        .replaceAll('p. m.', 'PM');
  }
}

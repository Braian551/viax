import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mensajes rápidos predefinidos para conductor
class ConductorQuickMessages {
  static const List<QuickMessage> messages = [
    QuickMessage(
      text: 'Ya llegué al punto de recogida',
      icon: Icons.location_on,
      color: Color(0xFF4CAF50),
    ),
    QuickMessage(
      text: 'Estoy en camino',
      icon: Icons.directions_car,
      color: Color(0xFF2196F3),
    ),
    QuickMessage(
      text: '¿Dónde te encuentras?',
      icon: Icons.search,
      color: Color(0xFFFF9800),
    ),
    QuickMessage(
      text: 'Espérame un momento',
      icon: Icons.access_time,
      color: Color(0xFF9C27B0),
    ),
    QuickMessage(
      text: 'Estoy afuera esperando',
      icon: Icons.person_pin_circle,
      color: Color(0xFF00BCD4),
    ),
    QuickMessage(
      text: 'No puedo estacionar aquí',
      icon: Icons.warning_rounded,
      color: Color(0xFFF44336),
    ),
  ];
}

/// Mensajes rápidos predefinidos para cliente
class ClienteQuickMessages {
  static const List<QuickMessage> messages = [
    QuickMessage(
      text: 'Ya bajo',
      icon: Icons.directions_walk,
      color: Color(0xFF4CAF50),
    ),
    QuickMessage(
      text: 'Estoy afuera esperando',
      icon: Icons.person_pin_circle,
      color: Color(0xFF2196F3),
    ),
    QuickMessage(
      text: 'Un momento por favor',
      icon: Icons.access_time,
      color: Color(0xFFFF9800),
    ),
    QuickMessage(
      text: '¿Dónde estás?',
      icon: Icons.search,
      color: Color(0xFF9C27B0),
    ),
    QuickMessage(
      text: 'Estoy en la entrada principal',
      icon: Icons.door_front_door,
      color: Color(0xFF00BCD4),
    ),
    QuickMessage(
      text: 'Voy con equipaje',
      icon: Icons.luggage,
      color: Color(0xFF795548),
    ),
  ];
}

/// Modelo de mensaje rápido
class QuickMessage {
  final String text;
  final IconData icon;
  final Color color;

  const QuickMessage({
    required this.text,
    required this.icon,
    required this.color,
  });
}

/// Tipo de usuario para determinar qué mensajes mostrar
enum ChatUserType { conductor, cliente }

/// Widget de mensajes rápidos estilo DiDi
class QuickMessagesBar extends StatefulWidget {
  final ChatUserType userType;
  final Function(String message) onMessageSelected;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const QuickMessagesBar({
    super.key,
    required this.userType,
    required this.onMessageSelected,
    this.isDark = false,
    this.isExpanded = false,
    this.onToggleExpand,
  });

  @override
  State<QuickMessagesBar> createState() => _QuickMessagesBarState();
}

class _QuickMessagesBarState extends State<QuickMessagesBar> {
  bool _isExpanded = false;

  List<QuickMessage> get _messages => widget.userType == ChatUserType.conductor
      ? ConductorQuickMessages.messages
      : ClienteQuickMessages.messages;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onToggleExpand?.call();
  }

  void _selectMessage(QuickMessage message) {
    HapticFeedback.mediumImpact();
    widget.onMessageSelected(message.text);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? const Color(0xFF1C1C1E)
        : Colors.white;
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: _isExpanded ? _buildExpandedView(borderColor) : _buildCompactView(borderColor),
    );
  }
  
  Widget _buildCompactView(Color borderColor) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _buildExpandButton(borderColor),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildCompactChip(_messages[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandedView(Color borderColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón para colapsar
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              _buildExpandButton(borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Mensajes rápidos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Grid de mensajes
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildExpandedGrid(),
        ),
      ],
    );
  }

  Widget _buildExpandButton(Color borderColor) {
    return SizedBox(
      width: 44,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleExpand,
          child: Icon(
            _isExpanded 
                ? Icons.keyboard_arrow_down_rounded 
                : Icons.keyboard_arrow_up_rounded,
            color: widget.isDark ? Colors.white70 : Colors.grey[600],
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactChip(QuickMessage message) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectMessage(message),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: message.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: message.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.icon,
                  size: 16,
                  color: message.color,
                ),
                const SizedBox(width: 6),
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _messages.map((message) {
        return _buildExpandedChip(message);
      }).toList(),
    );
  }

  Widget _buildExpandedChip(QuickMessage message) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectMessage(message),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: message.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: message.color.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: message.color.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: message.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  message.icon,
                  size: 18,
                  color: message.color,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget flotante de mensajes rápidos (alternativa compacta)
class QuickMessagesFloating extends StatelessWidget {
  final ChatUserType userType;
  final Function(String message) onMessageSelected;
  final bool isDark;

  const QuickMessagesFloating({
    super.key,
    required this.userType,
    required this.onMessageSelected,
    this.isDark = false,
  });

  List<QuickMessage> get _messages => userType == ChatUserType.conductor
      ? ConductorQuickMessages.messages.take(4).toList()
      : ClienteQuickMessages.messages.take(4).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _messages.map((message) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _QuickMessagePill(
                message: message,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onMessageSelected(message.text);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _QuickMessagePill extends StatelessWidget {
  final QuickMessage message;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickMessagePill({
    required this.message,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? message.color.withValues(alpha: 0.2)
                : message.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: message.color.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.icon,
                size: 16,
                color: message.color,
              ),
              const SizedBox(width: 6),
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

/// Mensajes globales sobrepuestos para asegurar visibilidad incluso sobre drags y modales.
class GlobalOverlayMessage {
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(context, message: message, isError: false, duration: duration);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(context, message: message, isError: true, duration: duration);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required bool isError,
    required Duration duration,
  }) {
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    _entry = OverlayEntry(
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final topOffset = mediaQuery.padding.top + 14;

        return Positioned(
          top: topOffset,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: _OverlayMessageCard(
                message: message,
                isError: isError,
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _dismissTimer = Timer(duration, hide);
  }

  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _OverlayMessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _OverlayMessageCard({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB00020) : const Color(0xFF1F8A3B);
    final icon = isError ? Icons.error_rounded : Icons.check_circle_rounded;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// lib/src/widgets/snackbars/custom_snackbar.dart
import 'package:flutter/material.dart';

enum SnackbarType {
  success,
  error,
  warning,
  info,
}

class CustomSnackbar {
  /// Muestra un snackbar personalizado
  static void show(
    BuildContext context, {
    required String message,
    required SnackbarType type,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final config = _getSnackbarConfig(type, isDark);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono con fondo suave
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: config.iconBackgroundColor,
                border: Border.all(color: config.iconBorderColor, width: 1),
              ),
              child: Center(
                child: Icon(
                  config.icon,
                  color: config.iconColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Mensaje
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: config.messageColor,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: config.borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 10,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: config.actionColor,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  /// Muestra un snackbar de éxito
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Muestra un snackbar de error
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Muestra un snackbar de advertencia
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Muestra un snackbar informativo
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackbarType.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static _SnackbarConfig _getSnackbarConfig(SnackbarType type, bool isDark) {
    final baseBg = isDark ? const Color(0xFF171A1D) : Colors.white;
    final messageColor = isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF2E3135);
    switch (type) {
      case SnackbarType.success:
        return _SnackbarConfig.success(baseBg, messageColor);
      case SnackbarType.error:
        return _SnackbarConfig.error(baseBg, messageColor);
      case SnackbarType.warning:
        return _SnackbarConfig.warning(baseBg, messageColor);
      case SnackbarType.info:
        return _SnackbarConfig.info(baseBg, messageColor);
    }
  }
}

class _SnackbarConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color iconBorderColor;
  final Color borderColor;
  final Color actionColor;
  final Color messageColor;
  final Color backgroundColor;

  _SnackbarConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.iconBorderColor,
    required this.borderColor,
    required this.actionColor,
    required this.messageColor,
    required this.backgroundColor,
  });

  factory _SnackbarConfig.success(Color bg, Color messageColor) {
    return _SnackbarConfig(
      icon: Icons.check_circle,
      iconColor: const Color(0xFF2E7D32),
      iconBackgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
      iconBorderColor: const Color(0xFF2E7D32).withValues(alpha: 0.45),
      borderColor: const Color(0xFF2E7D32).withValues(alpha: 0.6),
      actionColor: const Color(0xFF2E7D32),
      messageColor: messageColor,
      backgroundColor: bg,
    );
  }

  factory _SnackbarConfig.error(Color bg, Color messageColor) {
    return _SnackbarConfig(
      icon: Icons.error,
      iconColor: const Color(0xFFB00020),
      iconBackgroundColor: const Color(0xFFEF5350).withValues(alpha: 0.15),
      iconBorderColor: const Color(0xFFB00020).withValues(alpha: 0.45),
      borderColor: const Color(0xFFB00020).withValues(alpha: 0.65),
      actionColor: const Color(0xFFB00020),
      messageColor: messageColor,
      backgroundColor: bg,
    );
  }

  factory _SnackbarConfig.warning(Color bg, Color messageColor) {
    return _SnackbarConfig(
      icon: Icons.warning,
      iconColor: const Color(0xFFED6C02),
      iconBackgroundColor: const Color(0xFFFFA726).withValues(alpha: 0.15),
      iconBorderColor: const Color(0xFFED6C02).withValues(alpha: 0.45),
      borderColor: const Color(0xFFED6C02).withValues(alpha: 0.6),
      actionColor: const Color(0xFFED6C02),
      messageColor: messageColor,
      backgroundColor: bg,
    );
  }

  factory _SnackbarConfig.info(Color bg, Color messageColor) {
    return _SnackbarConfig(
      icon: Icons.info,
      iconColor: const Color(0xFF1565C0),
      iconBackgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
      iconBorderColor: const Color(0xFF1565C0).withValues(alpha: 0.45),
      borderColor: const Color(0xFF1565C0).withValues(alpha: 0.6),
      actionColor: const Color(0xFF1565C0),
      messageColor: messageColor,
      backgroundColor: bg,
    );
  }
}

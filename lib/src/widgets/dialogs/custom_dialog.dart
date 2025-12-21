// lib/src/widgets/dialogs/custom_dialog.dart
import 'package:flutter/material.dart';

enum DialogType {
  success,
  error,
  warning,
  info,
}

class CustomDialog extends StatelessWidget {
  final DialogType type;
  final String title;
  final String message;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final Widget? customIcon;
  final bool barrierDismissible;

  const CustomDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.primaryButtonText,
    this.secondaryButtonText,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.customIcon,
    this.barrierDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final config = _getDialogConfig(theme, isDark);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: config.borderColor.withValues(alpha: 0.28),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
                color: config.glowColor.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con icono
            Container(
              padding: const EdgeInsets.only(top: 28, bottom: 16),
              child: Column(
                children: [
                  // Icono con efecto de glow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: config.iconBackground,
                      border: Border.all(color: config.iconBorderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: config.glowColor.withValues(alpha: isDark ? 0.35 : 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Center(
                      child: customIcon ?? Icon(
                        config.icon,
                        size: 32,
                        color: config.iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  
                  // TÃ­tulo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: config.titleColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mensaje
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14.5,
                  height: 1.48,
                  letterSpacing: 0.15,
                  color: config.messageColor,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Botones
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  // BotÃ³n primario
                  if (primaryButtonText != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onPrimaryPressed ??
                            () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.primaryButtonColor,
                          foregroundColor: config.primaryButtonTextColor,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Text(
                          primaryButtonText!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: config.primaryButtonTextColor,
                          ),
                        ),
                      ),
                    ),

                  // BotÃ³n secundario
                  if (secondaryButtonText != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: config.secondaryButtonTextColor,
                          side: BorderSide(
                            color: config.secondaryButtonBorderColor,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Text(
                          secondaryButtonText!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: config.secondaryButtonTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DialogConfig _getDialogConfig(ThemeData theme, bool isDark) {
    // Base neutrals
    final surface = isDark ? const Color(0xFF17191C) : Colors.white;
    final messageColor = isDark ? Colors.white70 : const Color(0xFF424750);
    switch (type) {
      case DialogType.success:
        return _DialogConfig.success(surface, messageColor, theme.colorScheme.secondary);
      case DialogType.error:
        return _DialogConfig.error(surface, messageColor);
      case DialogType.warning:
        return _DialogConfig.warning(surface, messageColor);
      case DialogType.info:
        return _DialogConfig.info(surface, messageColor);
    }
  }
}

class _DialogConfig {
  final IconData icon;
  final Color iconColor;
  final Color titleColor;
  final Color borderColor;
  final Color glowColor;
  final Color primaryButtonColor;
  final Color primaryButtonTextColor;
  final Color backgroundColor;
  final Color messageColor;
  final Color iconBackground;
  final Color iconBorderColor;
  final Color secondaryButtonBorderColor;
  final Color secondaryButtonTextColor;

  _DialogConfig({
    required this.icon,
    required this.iconColor,
    required this.titleColor,
    required this.borderColor,
    required this.glowColor,
    required this.primaryButtonColor,
    required this.primaryButtonTextColor,
    required this.backgroundColor,
    required this.messageColor,
    required this.iconBackground,
    required this.iconBorderColor,
    required this.secondaryButtonBorderColor,
    required this.secondaryButtonTextColor,
  });

  factory _DialogConfig.success(Color surface, Color messageColor, Color accent) {
    return _DialogConfig(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2E7D32),
      titleColor: const Color(0xFF2E7D32),
      borderColor: const Color(0xFF2E7D32),
      glowColor: const Color(0xFF4CAF50),
      primaryButtonColor: const Color(0xFF2E7D32),
      primaryButtonTextColor: Colors.white,
      backgroundColor: surface,
      messageColor: messageColor,
      iconBackground: const Color(0xFF2E7D32).withValues(alpha: 0.12),
      iconBorderColor: const Color(0xFF2E7D32).withValues(alpha: 0.5),
      secondaryButtonBorderColor: const Color(0xFF2E7D32).withValues(alpha: 0.4),
      secondaryButtonTextColor: const Color(0xFF2E7D32),
    );
  }

  factory _DialogConfig.error(Color surface, Color messageColor) {
    return _DialogConfig(
      icon: Icons.error_outline,
      iconColor: const Color(0xFFB00020),
      titleColor: const Color(0xFFB00020),
      borderColor: const Color(0xFFB00020),
      glowColor: const Color(0xFFEF5350),
      primaryButtonColor: const Color(0xFFB00020),
      primaryButtonTextColor: Colors.white,
      backgroundColor: surface,
      messageColor: messageColor,
      iconBackground: const Color(0xFFB00020).withValues(alpha: 0.12),
      iconBorderColor: const Color(0xFFB00020).withValues(alpha: 0.5),
      secondaryButtonBorderColor: const Color(0xFFB00020).withValues(alpha: 0.4),
      secondaryButtonTextColor: const Color(0xFFB00020),
    );
  }

  factory _DialogConfig.warning(Color surface, Color messageColor) {
    return _DialogConfig(
      icon: Icons.warning_amber_outlined,
      iconColor: const Color(0xFFED6C02),
      titleColor: const Color(0xFFED6C02),
      borderColor: const Color(0xFFED6C02),
      glowColor: const Color(0xFFFFA726),
      primaryButtonColor: const Color(0xFFED6C02),
      primaryButtonTextColor: Colors.white,
      backgroundColor: surface,
      messageColor: messageColor,
      iconBackground: const Color(0xFFED6C02).withValues(alpha: 0.12),
      iconBorderColor: const Color(0xFFED6C02).withValues(alpha: 0.5),
      secondaryButtonBorderColor: const Color(0xFFED6C02).withValues(alpha: 0.4),
      secondaryButtonTextColor: const Color(0xFFED6C02),
    );
  }

  factory _DialogConfig.info(Color surface, Color messageColor) {
    return _DialogConfig(
      icon: Icons.info_outline,
      iconColor: const Color(0xFF1565C0),
      titleColor: const Color(0xFF1565C0),
      borderColor: const Color(0xFF1565C0),
      glowColor: const Color(0xFF42A5F5),
      primaryButtonColor: const Color(0xFF1565C0),
      primaryButtonTextColor: Colors.white,
      backgroundColor: surface,
      messageColor: messageColor,
      iconBackground: const Color(0xFF1565C0).withValues(alpha: 0.12),
      iconBorderColor: const Color(0xFF1565C0).withValues(alpha: 0.5),
      secondaryButtonBorderColor: const Color(0xFF1565C0).withValues(alpha: 0.4),
      secondaryButtonTextColor: const Color(0xFF1565C0),
    );
  }
}

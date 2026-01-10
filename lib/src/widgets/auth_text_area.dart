import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Campo de texto multilínea (textarea) reutilizable para pantallas de autenticación.
/// Basado en AuthTextField pero optimizado para texto largo con icono alineado arriba.
class AuthTextArea extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool isLast;
  final bool enabled;
  final bool readOnly;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int minLines;
  final int maxLines;

  const AuthTextArea({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.isLast = false,
    this.enabled = true,
    this.readOnly = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.minLines = 3,
    this.maxLines = 5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark 
              ? AppColors.darkSurface.withValues(alpha: 0.8) 
              : AppColors.lightSurface.withValues(alpha: 0.8),
            isDark 
              ? AppColors.darkCard.withValues(alpha: 0.4) 
              : AppColors.lightCard.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.darkShadow : AppColors.lightShadow,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono alineado arriba
            Container(
              margin: const EdgeInsets.only(top: 4, right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            // Campo de texto expandido
            Expanded(
              child: TextFormField(
                controller: controller,
                inputFormatters: inputFormatters,
                textCapitalization: textCapitalization,
                keyboardType: keyboardType ?? TextInputType.multiline,
                enabled: enabled,
                readOnly: readOnly,
                minLines: minLines,
                maxLines: maxLines,
                textInputAction: isLast ? TextInputAction.done : TextInputAction.newline,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  alignLabelWithHint: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  isCollapsed: true,
                  filled: false,
                ),
                validator: validator,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

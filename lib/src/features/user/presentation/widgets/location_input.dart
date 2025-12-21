import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

typedef OnClearCallback = void Function();

class LocationInput extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String placeholder;
  final bool isDark;
  final VoidCallback onTap;
  final OnClearCallback? onClear;
  final bool isDestination;
  final bool isEditing;
  final TextEditingController? textController;
  final FocusNode? focusNode;
  final VoidCallback? onClearInput;

  const LocationInput({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.isDark,
    required this.onTap,
    this.onClear,
    this.isDestination = false,
    this.isEditing = false,
    this.textController,
    this.focusNode,
    this.onClearInput,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final bgColor = isDark ? AppColors.darkCard : AppColors.lightBackground; // use unified card color
    final borderDefault = AppColors.primary.withValues(alpha: 0.06);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? bgColor.withValues(alpha: 0.06) : bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEditing
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : borderDefault,
                width: isEditing ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (isEditing) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (textController != null && textController!.text.isNotEmpty)
                    GestureDetector(
                      onTap: onClearInput,
                      child: Icon(
                        Icons.close,
                        color: textColor.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                ] else ...[
                  if (isDestination) ...[
                    Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white70 : AppColors.primary,
                    ),
                  ] else ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: TextStyle(
                        color: value != null ? textColor : (isDark ? Colors.white54 : Colors.grey[500]),
                        fontSize: 16,
                        fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (value != null && onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(
                        Icons.close,
                        color: textColor.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

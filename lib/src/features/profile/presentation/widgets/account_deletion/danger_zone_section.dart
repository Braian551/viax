import 'package:flutter/material.dart';
import 'package:viax/src/features/profile/presentation/widgets/account_deletion/delete_account_button.dart';

class DangerZoneSection extends StatelessWidget {
  final VoidCallback onDeletePressed;

  const DangerZoneSection({
    super.key,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zona de riesgo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si confirmas la eliminación, tu cuenta pasará a estado pendiente por 15 días. Después de ese plazo, se eliminará de forma irreversible.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          DeleteAccountButton(onPressed: onDeletePressed),
        ],
      ),
    );
  }
}

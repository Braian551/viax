import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Overlay de carga con indicador circular.
/// 
/// Cubre la pantalla con un fondo semitransparente mientras
/// se realizan operaciones asíncronas.
class LoadingOverlay extends StatelessWidget {
  final bool isDark;
  final String message;

  const LoadingOverlay({
    super.key,
    required this.isDark,
    this.message = 'Calculando ruta...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

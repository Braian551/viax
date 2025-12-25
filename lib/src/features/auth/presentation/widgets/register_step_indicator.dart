import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class RegisterStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;

  const RegisterStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepTitles = const ['Personal', 'Contacto', 'Seguridad'],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: SizedBox(
        width: 320, // Increased width for "longer" look
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            final isActive = index == currentStep;
            final isCompleted = index < currentStep;
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive || isCompleted 
                        ? AppColors.primary 
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                    boxShadow: isActive ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Center(
                    child: isCompleted 
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                // Connector Line (except for last step)
                if (index < totalSteps - 1)
                  Container(
                    height: 3,
                    width: 70, // Increased line length
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCompleted 
                          ? AppColors.primary 
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

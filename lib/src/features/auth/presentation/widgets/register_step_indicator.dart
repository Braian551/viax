import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class RegisterStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const RegisterStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps * 2 - 1, (index) {
        // Even indices are circles (0, 2, 4...)
        // Odd indices are lines (1, 3, 5...)
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == currentStep;
          final isCompleted = stepIndex < currentStep;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28, 
            height: 28,
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
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          );
        } else {
          // Line
          final stepIndex = (index - 1) ~/ 2; 
          // The line connects stepIndex to stepIndex + 1
          // It should be colored if the NEXT step is at least current or completed?
          // Actually, if step 0 is done, the line to 1 should be colored if we are at 1.
          
          final isLineCompleted = stepIndex < currentStep;

          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isLineCompleted 
                    ? AppColors.primary 
                    : (isDark ? Colors.white10 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
      }),
    );
  }
}

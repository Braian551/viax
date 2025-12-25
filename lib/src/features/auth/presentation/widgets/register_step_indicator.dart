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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Background Track
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white10 
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Validating / Completed Track
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate width based on progress
                // Step 0: 33% (1/3), Step 1: 66%, Step 2: 100%
                final double progress = (currentStep + 1) / totalSteps;
                final double width = constraints.maxWidth * progress;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                  height: 4,
                  width: width,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

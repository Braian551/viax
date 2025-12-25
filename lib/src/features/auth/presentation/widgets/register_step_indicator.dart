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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isPassed = index < currentStep;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            decoration: BoxDecoration(
               color: isActive || isPassed 
                  ? AppColors.primary 
                  : AppColors.primary.withOpacity(0.2),
               borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

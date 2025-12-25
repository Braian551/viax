import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class BiometricProgressBar extends StatelessWidget {
  final double progress;

  const BiometricProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
         double threshold = (index + 1) / 4.0;
         bool active = progress >= (index / 4.0);
         bool completed = progress >= threshold;
         
         return AnimatedContainer(
           duration: const Duration(milliseconds: 300),
           margin: const EdgeInsets.symmetric(horizontal: 4),
           height: 6,
           width: completed ? 20 : (active ? 40 : 12),
           decoration: BoxDecoration(
             color: completed ? Colors.green : (active ? AppColors.primary : Colors.grey.withOpacity(0.3)),
             borderRadius: BorderRadius.circular(3),
           ),
         );
      }),
    );
  }
}

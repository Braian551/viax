import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../theme/app_colors.dart';

class ConductorCardShimmer extends StatelessWidget {
  const ConductorCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final cardColor = isDark 
        ? AppColors.darkSurface.withValues(alpha: 0.8)
        : AppColors.lightSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Name/Email + Status Badge
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Info Rows (License, Plate)
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(width: 14, height: 14, color: Colors.white),
                      const SizedBox(width: 8),
                      Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Container(width: 40, height: 10, color: Colors.white),
                           const SizedBox(height: 4),
                           Container(width: 60, height: 12, color: Colors.white),
                         ],
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(width: 14, height: 14, color: Colors.white),
                      const SizedBox(width: 8),
                      Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Container(width: 40, height: 10, color: Colors.white),
                           const SizedBox(height: 4),
                           Container(width: 60, height: 12, color: Colors.white),
                         ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Document Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 80, height: 12, color: Colors.white),
                Container(width: 30, height: 12, color: Colors.white),
              ],
            ),
            const SizedBox(height: 6),
            Container(height: 6, color: Colors.white),
            
            const SizedBox(height: 16),
            
            // Actions Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

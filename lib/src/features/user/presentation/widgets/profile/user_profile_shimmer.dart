import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class UserProfileShimmer extends StatelessWidget {
  const UserProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final baseColor = isDark 
        ? const Color(0xFF242424) 
        : const Color(0xFFEEEEEE);
        
    final highlightColor = isDark 
        ? const Color(0xFF383838) 
        : const Color(0xFFF5F5F5);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Mi Perfil" Title
          _ShimmerBox(
            width: 140,
            height: 32,
            baseColor: baseColor,
            highlightColor: highlightColor,
          ),
          const SizedBox(height: 24),

          // User Card
          _buildShimmerCard(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              children: [
                _ShimmerCircle(
                  size: 70,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShimmerBox(
                        width: 120,
                        height: 20,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                      const SizedBox(height: 8),
                      _ShimmerBox(
                        width: double.infinity,
                        height: 14,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Rating Section
          _buildShimmerCard(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShimmerBox(
                        width: 80,
                        height: 14,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                      const SizedBox(height: 8),
                      _ShimmerBox(
                        width: 60,
                        height: 24,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                    ],
                  ),
                ),
                _ShimmerBox(
                  width: 80,
                  height: 28,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  borderRadius: 12,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Promotional Card (Become Driver)
          _ShimmerBox(
            width: double.infinity,
            height: 100,
            baseColor: baseColor,
            highlightColor: highlightColor,
            borderRadius: 24,
          ),

          const SizedBox(height: 32),

          // "Configuración" Title
          _ShimmerBox(
            width: 120,
            height: 20,
            baseColor: baseColor,
            highlightColor: highlightColor,
          ),
          const SizedBox(height: 16),

          // Option Tiles
          ...List.generate(5, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShimmerBox(
              width: double.infinity,
              height: 70,
              baseColor: baseColor,
              highlightColor: highlightColor,
              borderRadius: 16,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildShimmerCard({
    required Color baseColor,
    required Color highlightColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double size;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerCircle({
    required this.size,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

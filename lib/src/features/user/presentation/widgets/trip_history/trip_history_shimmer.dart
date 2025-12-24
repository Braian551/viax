import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Skeleton loading shimmer effect para la lista de viajes
class TripHistoryShimmer extends StatefulWidget {
  final int itemCount;
  final bool isDark;

  const TripHistoryShimmer({
    super.key,
    this.itemCount = 4,
    this.isDark = false,
  });

  @override
  State<TripHistoryShimmer> createState() => _TripHistoryShimmerState();
}

class _TripHistoryShimmerState extends State<TripHistoryShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            return _ShimmerCard(
              animation: _animation,
              delay: index * 0.1,
              isDark: widget.isDark,
            );
          },
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final Animation<double> animation;
  final double delay;
  final bool isDark;

  const _ShimmerCard({
    required this.animation,
    required this.delay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark 
        ? AppColors.darkSurface.withOpacity(0.6)
        : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.2)
        : Colors.black.withOpacity(0.03);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              _ShimmerBox(
                width: 44,
                height: 44,
                borderRadius: 12,
                animation: animation,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      width: 80,
                      height: 16,
                      animation: animation,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    _ShimmerBox(
                      width: 120,
                      height: 12,
                      animation: animation,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ShimmerBox(
                    width: 70,
                    height: 18,
                    animation: animation,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _ShimmerBox(
                    width: 60,
                    height: 16,
                    borderRadius: 8,
                    animation: animation,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          _ShimmerBox(
            width: double.infinity,
            height: 1,
            animation: animation,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          // Origin
          Row(
            children: [
              _ShimmerBox(
                width: 24,
                height: 24,
                borderRadius: 12,
                animation: animation,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: 14,
                  animation: animation,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Line
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: _ShimmerBox(
              width: 2,
              height: 20,
              animation: animation,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 8),
          // Destination
          Row(
            children: [
              _ShimmerBox(
                width: 24,
                height: 24,
                borderRadius: 12,
                animation: animation,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: 14,
                  animation: animation,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Info chips
          Row(
            children: [
              _ShimmerBox(
                width: 60,
                height: 24,
                borderRadius: 8,
                animation: animation,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _ShimmerBox(
                width: 60,
                height: 24,
                borderRadius: 8,
                animation: animation,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _ShimmerBox(
                width: 70,
                height: 24,
                borderRadius: 8,
                animation: animation,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Animation<double> animation;
  final bool isDark;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 6,
    required this.animation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark 
        ? AppColors.darkBackground 
        : AppColors.lightBackground;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(animation.value - 1, 0),
          end: Alignment(animation.value + 1, 0),
          colors: [
            baseColor.withOpacity(isDark ? 0.3 : 0.5),
            baseColor.withOpacity(isDark ? 0.1 : 0.2),
            baseColor.withOpacity(isDark ? 0.3 : 0.5),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

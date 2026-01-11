import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

class ReportsShimmer extends StatefulWidget {
  const ReportsShimmer({super.key});

  @override
  State<ReportsShimmer> createState() => _ReportsShimmerState();
}

class _ReportsShimmerState extends State<ReportsShimmer>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSectionTitleShimmer(isDark),
        _buildSummaryCardsShimmer(isDark),
        const SizedBox(height: 24),
        _buildSectionTitleShimmer(isDark),
        _buildChartCardShimmer(isDark),
        const SizedBox(height: 24),
        _buildSectionTitleShimmer(isDark),
        _buildListShimmer(isDark, count: 3),
        const SizedBox(height: 24),
        _buildSectionTitleShimmer(isDark),
        _buildChartCardShimmer(isDark, height: 200),
      ]),
    );
  }

  Widget _buildSectionTitleShimmer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: _ShimmerBox(
        width: 150,
        height: 20,
        animation: _animation,
        isDark: isDark,
      ),
    );
  }

  Widget _buildSummaryCardsShimmer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSingleSummaryCardShimmer(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSingleSummaryCardShimmer(isDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSingleSummaryCardShimmer(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSingleSummaryCardShimmer(isDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSingleSummaryCardShimmer(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSingleSummaryCardShimmer(isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSummaryCardShimmer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerBox(
                width: 36,
                height: 36,
                borderRadius: 10,
                animation: _animation,
                isDark: isDark,
              ),
              _ShimmerBox(
                width: 40,
                height: 18,
                borderRadius: 8,
                animation: _animation,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ShimmerBox(
            width: 80,
            height: 24,
            animation: _animation,
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _ShimmerBox(
            width: 60,
            height: 14,
            animation: _animation,
            isDark: isDark,
          ),
          const SizedBox(height: 4),
          _ShimmerBox(
            width: 50,
            height: 12,
            animation: _animation,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCardShimmer(bool isDark, {double height = 250}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(
                  width: 100,
                  height: 18,
                  animation: _animation,
                  isDark: isDark,
                ),
                _ShimmerBox(
                  width: 80,
                  height: 32,
                  borderRadius: 10,
                  animation: _animation,
                  isDark: isDark,
                ),
              ],
            ),
            const Spacer(),
            _ShimmerBox(
              width: double.infinity,
              height: height - 100,
              borderRadius: 12,
              animation: _animation,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListShimmer(bool isDark, {int count = 3}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(count, (index) => _buildListItemShimmer(isDark)),
      ),
    );
  }

  Widget _buildListItemShimmer(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _ShimmerBox(
            width: 48,
            height: 48,
            borderRadius: 24,
            animation: _animation,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  width: 120,
                  height: 16,
                  animation: _animation,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _ShimmerBox(
                  width: 80,
                  height: 12,
                  animation: _animation,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          _ShimmerBox(
            width: 60,
            height: 20,
            borderRadius: 8,
            animation: _animation,
            isDark: isDark,
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
        ? AppColors.darkBackground.withValues(alpha: 0.5)
        : Colors.grey.withValues(alpha: 0.2);

    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(animation.value - 1, 0),
              end: Alignment(animation.value + 1, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

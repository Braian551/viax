import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Widget de carga shimmer reutilizable para diferentes secciones.
/// Provee efectos de carga elegantes estilo skeleton.
class ShimmerLoading extends StatelessWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
      highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

/// Caja shimmer con forma redondeada.
class ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer circular (para avatares).
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
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

/// Shimmer de tarjeta de estadística (para dashboards).
class ShimmerStatCard extends StatelessWidget {
  const ShimmerStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

/// Shimmer de lista de actividad.
class ShimmerActivityList extends StatelessWidget {
  final int itemCount;

  const ShimmerActivityList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShimmerLoading(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer completo para un dashboard (header + grid + lista).
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Welcome shimmer
          const ShimmerBox(height: 80, borderRadius: 24),
          const SizedBox(height: 28),
          // Title shimmer
          const ShimmerBox(height: 22, width: 180),
          const SizedBox(height: 20),
          // Stats grid shimmer
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.3,
            children: const [
              ShimmerStatCard(),
              ShimmerStatCard(),
              ShimmerStatCard(),
              ShimmerStatCard(),
            ],
          ),
          const SizedBox(height: 28),
          // Activity title shimmer
          const ShimmerBox(height: 22, width: 160),
          const SizedBox(height: 16),
          // Activity list shimmer
          const ShimmerActivityList(),
        ],
      ),
    );
  }
}

/// Shimmer para la sección de perfil.
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Avatar + name shimmer
          Row(
            children: [
              const ShimmerCircle(size: 72),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(height: 22, width: 160),
                    SizedBox(height: 8),
                    ShimmerBox(height: 14, width: 120),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Info cards shimmer
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: ShimmerBox(height: 72),
            ),
          ),
          const SizedBox(height: 24),
          const ShimmerBox(height: 22, width: 140),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerBox(height: 56),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer para sección de gestión/menú.
class ManagementShimmer extends StatelessWidget {
  const ManagementShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const ShimmerBox(height: 28, width: 200),
          const SizedBox(height: 8),
          const ShimmerBox(height: 16, width: 280),
          const SizedBox(height: 28),
          ...List.generate(
            6,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: ShimmerBox(height: 80),
            ),
          ),
        ],
      ),
    );
  }
}

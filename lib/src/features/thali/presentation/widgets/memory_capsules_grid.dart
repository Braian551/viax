import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/thali_colors.dart';

class MemoryCapsule {
  final String title;
  final String preview;
  final String fullText;
  final IconData icon;

  const MemoryCapsule({
    required this.title,
    required this.preview,
    required this.fullText,
    required this.icon,
  });
}

/// Interactive grid of memory capsules. Tapping a capsule opens a detail modal.
class MemoryCapsulesGrid extends StatelessWidget {
  final List<MemoryCapsule> capsules;

  const MemoryCapsulesGrid({super.key, required this.capsules});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: capsules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final capsule = capsules[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 360 + (index * 80)),
          tween: Tween(begin: 0, end: 1),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 22 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _CapsuleCard(capsule: capsule),
        );
      },
    );
  }
}

class _CapsuleCard extends StatefulWidget {
  final MemoryCapsule capsule;

  const _CapsuleCard({required this.capsule});

  @override
  State<_CapsuleCard> createState() => _CapsuleCardState();
}

class _CapsuleCardState extends State<_CapsuleCard> {
  bool _pressed = false;

  Future<void> _openDetail() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CapsuleDetailSheet(capsule: widget.capsule),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: _openDetail,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ThaliColors.bgCardLight,
                ThaliColors.bgCard,
              ],
            ),
            border: Border.all(
              color: ThaliColors.purple.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: ThaliColors.purple.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: ThaliColors.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.capsule.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                widget.capsule.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ThaliColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  widget.capsule.preview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ThaliColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tocar para abrir',
                style: TextStyle(
                  color: ThaliColors.pink.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleDetailSheet extends StatelessWidget {
  final MemoryCapsule capsule;

  const _CapsuleDetailSheet({required this.capsule});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      decoration: BoxDecoration(
        color: ThaliColors.bgDark,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ThaliColors.purple.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ThaliColors.purple.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: ThaliColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(capsule.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  capsule.title,
                  style: const TextStyle(
                    color: ThaliColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            capsule.fullText,
            style: const TextStyle(
              color: ThaliColors.textSecondary,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

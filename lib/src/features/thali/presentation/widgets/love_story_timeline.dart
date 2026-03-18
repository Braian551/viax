import 'package:flutter/material.dart';
import '../theme/thali_colors.dart';

/// A single milestone in the love story timeline
class StoryMilestone {
  final String title;
  final String description;
  final IconData icon;

  const StoryMilestone({
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Vertical timeline displaying the love story milestones
class LoveStoryTimeline extends StatelessWidget {
  final List<StoryMilestone> milestones;

  const LoveStoryTimeline({super.key, required this.milestones});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(milestones.length, (index) {
        final milestone = milestones[index];
        final isLast = index == milestones.length - 1;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 500 + index * 200),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(-40 * (1 - value), 0),
                child: child,
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line + dot
                SizedBox(
                  width: 48,
                  child: Column(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: ThaliColors.accentGradient,
                          boxShadow: [
                            BoxShadow(
                              color: ThaliColors.purple.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  ThaliColors.purple,
                                  ThaliColors.purple.withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: ThaliColors.cardGradient,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ThaliColors.purple.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                milestone.icon,
                                color: ThaliColors.pink,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  milestone.title,
                                  style: const TextStyle(
                                    color: ThaliColors.pink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            milestone.description,
                            style: const TextStyle(
                              color: ThaliColors.textSecondary,
                              fontSize: 13.5,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/thali_colors.dart';

/// A glowing love message card with Kuromi-inspired styling
class LoveMessageCard extends StatefulWidget {
  final String message;
  final IconData icon;
  final int animationIndex;

  const LoveMessageCard({
    super.key,
    required this.message,
    this.icon = Icons.favorite,
    this.animationIndex = 0,
  });

  @override
  State<LoveMessageCard> createState() => _LoveMessageCardState();
}

class _LoveMessageCardState extends State<LoveMessageCard> {
  bool _expanded = false;

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + widget.animationIndex * 150),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _toggleExpand,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: ThaliColors.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _expanded
                  ? ThaliColors.pink.withValues(alpha: 0.55)
                  : ThaliColors.purple.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: (_expanded ? ThaliColors.pink : ThaliColors.purple)
                    .withValues(alpha: _expanded ? 0.22 : 0.15),
                blurRadius: _expanded ? 26 : 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: ThaliColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      firstChild: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ThaliColors.textPrimary,
                          fontSize: 15,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      secondChild: Text(
                        widget.message,
                        style: const TextStyle(
                          color: ThaliColors.textPrimary,
                          fontSize: 15,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          _expanded ? 'Toca para contraer' : 'Toca para expandir',
                          style: TextStyle(
                            color: ThaliColors.pink.withValues(alpha: 0.85),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: ThaliColors.pink,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

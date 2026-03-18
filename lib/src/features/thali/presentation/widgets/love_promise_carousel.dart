import 'package:flutter/material.dart';
import '../theme/thali_colors.dart';

class LovePromise {
  final String title;
  final String text;
  final IconData icon;

  const LovePromise({
    required this.title,
    required this.text,
    required this.icon,
  });
}

/// Swipeable promise cards to make the experience playful and interactive.
class LovePromiseCarousel extends StatefulWidget {
  final List<LovePromise> promises;

  const LovePromiseCarousel({super.key, required this.promises});

  @override
  State<LovePromiseCarousel> createState() => _LovePromiseCarouselState();
}

class _LovePromiseCarouselState extends State<LovePromiseCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.promises.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, i) {
              final promise = widget.promises[i];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var scale = 1.0;
                  if (_controller.position.haveDimensions) {
                    final page = _controller.page ?? _index.toDouble();
                    scale = (1 - (page - i).abs() * 0.10).clamp(0.9, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4B1F73),
                        Color(0xFF331E5C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: ThaliColors.pink.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ThaliColors.purple.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: ThaliColors.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(promise.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        promise.title,
                        style: const TextStyle(
                          color: ThaliColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        promise.text,
                        style: const TextStyle(
                          color: ThaliColors.textSecondary,
                          height: 1.55,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.promises.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: active ? ThaliColors.accentGradient : null,
                color: active ? null : ThaliColors.purple.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

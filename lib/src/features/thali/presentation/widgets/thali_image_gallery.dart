import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/thali_colors.dart';

/// Distributed collage of Kuromi images (non-carousel).
class ThaliImageGallery extends StatefulWidget {
  final List<String> assetPaths;

  const ThaliImageGallery({super.key, required this.assetPaths});

  @override
  State<ThaliImageGallery> createState() => _ThaliImageGalleryState();
}

class _ThaliImageGalleryState extends State<ThaliImageGallery> {
  void _openFullscreen(int startIndex) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => _FullscreenGallery(
        images: widget.assetPaths,
        initialIndex: startIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = (width - 64) / 2;
    final left = <String>[];
    final right = <String>[];
    for (int i = 0; i < widget.assetPaths.length; i++) {
      if (i.isEven) {
        left.add(widget.assetPaths[i]);
      } else {
        right.add(widget.assetPaths[i]);
      }
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: List.generate(left.length, (i) {
                  final globalIndex = i * 2;
                  return _CollageCard(
                    width: cardWidth,
                    imagePath: left[i],
                    index: globalIndex,
                    onTap: () => _openFullscreen(globalIndex),
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: List.generate(right.length, (i) {
                  final globalIndex = (i * 2) + 1;
                  return _CollageCard(
                    width: cardWidth,
                    imagePath: right[i],
                    index: globalIndex,
                    onTap: () => _openFullscreen(globalIndex),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: ThaliColors.bgCardLight.withValues(alpha: 0.8),
            border: Border.all(color: ThaliColors.purple.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'Toca cualquier imagen para verla en grande',
            style: TextStyle(
              color: ThaliColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CollageCard extends StatelessWidget {
  final double width;
  final String imagePath;
  final int index;
  final VoidCallback onTap;

  const _CollageCard({
    required this.width,
    required this.imagePath,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final heights = [220.0, 170.0, 210.0, 180.0];
    final rotations = [-0.03, 0.02, 0.015, -0.02];
    final h = heights[index % heights.length];
    final rot = rotations[index % rotations.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 350 + (index * 80)),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: onTap,
          child: Transform.rotate(
            angle: rot,
            child: Container(
              width: width,
              height: h,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4F2C79), Color(0xFF2E1D4F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ThaliColors.purple.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: Colors.black,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.asset(widget.images[i], fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1}/${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

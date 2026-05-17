import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/theme/app_colors.dart';

class DraggableNavItem {
  final IconData icon;
  final String label;

  const DraggableNavItem({required this.icon, required this.label});
}

class DraggableNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final bool isDark;
  final List<DraggableNavItem> items;

  const DraggableNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.isDark,
    required this.items,
  });

  @override
  State<DraggableNavBar> createState() => _DraggableNavBarState();
}

class _DraggableNavBarState extends State<DraggableNavBar>
    with TickerProviderStateMixin {
  final GlobalKey _gestureAreaKey = GlobalKey();
  late final LongPressGestureRecognizer _longPressRecognizer;
  late List<GlobalKey> _itemKeys;
  List<Rect> _itemRects = const [];
  bool _isDragging = false;
  double _dragOffsetX = 0.0;
  late int _draggingIndex;
  double _dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _draggingIndex = widget.currentIndex;
    _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    _longPressRecognizer =
        LongPressGestureRecognizer(duration: const Duration(milliseconds: 200))
          ..onLongPressStart = _onDragStart
          ..onLongPressMoveUpdate = _onDragUpdate
          ..onLongPressEnd = _onDragEnd;
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(covariant DraggableNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    }
    if (!_isDragging) {
      _draggingIndex = widget.currentIndex;
    }
    _scheduleMeasurement();
  }

  @override
  void dispose() {
    _longPressRecognizer.dispose();
    super.dispose();
  }

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _measureItemRects();
    });
  }

  void _measureItemRects() {
    final rootContext = _gestureAreaKey.currentContext;
    final rootBox = rootContext?.findRenderObject() as RenderBox?;
    if (rootBox == null || !rootBox.hasSize) {
      return;
    }

    final rects = <Rect>[];
    for (final key in _itemKeys) {
      final context = key.currentContext;
      final box = context?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final topLeft = rootBox.globalToLocal(box.localToGlobal(Offset.zero));
      rects.add(topLeft & box.size);
    }

    if (_sameRects(_itemRects, rects)) {
      return;
    }

    setState(() {
      _itemRects = rects;
    });
  }

  bool _sameRects(List<Rect> left, List<Rect> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      final current = left[index];
      final next = right[index];
      if ((current.left - next.left).abs() > 0.5 ||
          (current.top - next.top).abs() > 0.5 ||
          (current.width - next.width).abs() > 0.5 ||
          (current.height - next.height).abs() > 0.5) {
        return false;
      }
    }

    return true;
  }

  Rect? _rectForIndex(int index) {
    if (index < 0 || index >= _itemRects.length) {
      return null;
    }
    return _itemRects[index];
  }

  void _onDragStart(LongPressStartDetails details) {
    final activeRect = _rectForIndex(widget.currentIndex);
    if (activeRect == null || !activeRect.contains(details.localPosition)) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isDragging = true;
      _dragOffsetX = 0.0;
      _draggingIndex = widget.currentIndex;
      _dragStartX = details.localPosition.dx;
    });
  }

  void _onDragUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragging) {
      return;
    }

    final activeRect = _rectForIndex(widget.currentIndex);
    final firstRect = _itemRects.isNotEmpty ? _itemRects.first : null;
    final lastRect = _itemRects.isNotEmpty ? _itemRects.last : null;
    if (activeRect == null || firstRect == null || lastRect == null) {
      return;
    }

    final unclampedOffset = details.localPosition.dx - _dragStartX;
    final minOffset = firstRect.left - activeRect.left;
    final maxOffset = lastRect.left - activeRect.left;
    final nextOffset = unclampedOffset.clamp(minOffset, maxOffset).toDouble();
    final nextIndex = _closestIndex(details.localPosition.dx);

    if (nextIndex != _draggingIndex) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _draggingIndex = nextIndex;
      _dragOffsetX = nextOffset;
    });
  }

  int _closestIndex(double positionX) {
    if (_itemRects.isEmpty) {
      return widget.currentIndex;
    }

    var bestIndex = widget.currentIndex;
    var bestDistance = double.infinity;
    for (var index = 0; index < _itemRects.length; index++) {
      final distance = (_itemRects[index].center.dx - positionX).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  void _onDragEnd(LongPressEndDetails details) {
    if (!_isDragging) {
      return;
    }

    final targetIndex = _draggingIndex;
    setState(() {
      _isDragging = false;
      _dragOffsetX = 0.0;
    });

    if (targetIndex != widget.currentIndex) {
      widget.onTabChanged(targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRect = _rectForIndex(widget.currentIndex);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      decoration: BoxDecoration(
        color: (widget.isDark ? AppColors.darkCard : Colors.white).withValues(
          alpha: 0.75,
        ),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: (widget.isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(
          color: (widget.isDark ? Colors.white : Colors.black).withValues(
            alpha: 0.05,
          ),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => _longPressRecognizer,
                      (LongPressGestureRecognizer instance) {
                        instance.onLongPressStart = _onDragStart;
                        instance.onLongPressMoveUpdate = _onDragUpdate;
                        instance.onLongPressEnd = _onDragEnd;
                      },
                    ),
              },
              child: SizedBox(
                key: _gestureAreaKey,
                child: Stack(
                  children: [
                    if (activeRect != null)
                      Positioned(
                        left: activeRect.left,
                        top: activeRect.top,
                        width: activeRect.width,
                        height: activeRect.height,
                        child: IgnorePointer(
                          child: Transform.translate(
                            offset: Offset(_isDragging ? _dragOffsetX : 0, 0),
                            child: _buildSelector(),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(widget.items.length, (index) {
                        return _buildNavItem(index, widget.items[index]);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelector() {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.primary.withValues(alpha: 0.28)
            : AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(25),
        border: widget.isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1)
            : null,
        boxShadow: widget.isDark
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildNavItem(int index, DraggableNavItem item) {
    final isSelected = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => widget.onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: _itemKeys[index],
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 12,
        ),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 1.0 + (value * 0.15),
                  child: Icon(
                    item.icon,
                    color: isSelected
                        ? (widget.isDark ? Colors.white : AppColors.primary)
                        : (widget.isDark ? Colors.white70 : Colors.grey[400]),
                    size: 26,
                  ),
                );
              },
            ),
            if (isSelected) ...[
              const SizedBox(width: 10),
              Flexible(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.white
                              : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
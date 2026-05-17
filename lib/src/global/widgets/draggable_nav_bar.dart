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
  late final AnimationController _selectorAnimationController;
  late List<GlobalKey> _itemKeys;
  List<Rect> _itemRects = const [];
  double _gestureAreaWidth = 0.0;
  bool _isDragging = false;
  double _dragOffsetX = 0.0;
  late int _draggingIndex;
  int _dragStartIndex = 0;
  Rect? _dragStartRect;
  double _dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _draggingIndex = widget.currentIndex;
    _dragStartIndex = widget.currentIndex;
    _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    _selectorAnimationController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (!mounted) {
          return;
        }
        setState(() {
          _dragOffsetX = _selectorAnimationController.value;
        });
      });
    _longPressRecognizer =
        LongPressGestureRecognizer(duration: const Duration(milliseconds: 0))
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
      _dragStartIndex = widget.currentIndex;
      _dragStartRect = null;
    }
    _scheduleMeasurement();
  }

  @override
  void dispose() {
    _selectorAnimationController.dispose();
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

    final nextWidth = rootBox.size.width;
    final widthChanged = (_gestureAreaWidth - nextWidth).abs() > 0.5;
    if (!widthChanged && _sameRects(_itemRects, rects)) {
      return;
    }

    setState(() {
      _itemRects = rects;
      _gestureAreaWidth = nextWidth;
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

  double? _leftForIndex(int index) {
    return _rectForIndex(index)?.left;
  }

  double? _centerForIndex(int index) {
    return _rectForIndex(index)?.center.dx;
  }

  double? _tabWidth() {
    if (_gestureAreaWidth <= 0 || widget.items.isEmpty) {
      return null;
    }
    return _gestureAreaWidth / widget.items.length;
  }

  int _indexForOffset(double offset) {
    final startRect = _dragStartRect ?? _rectForIndex(_dragStartIndex);
    if (startRect != null && _itemRects.length == widget.items.length) {
      final targetCenter = startRect.center.dx + offset;
      var closestIndex = widget.currentIndex;
      var closestDistance = double.infinity;

      for (var index = 0; index < _itemRects.length; index++) {
        final center = _centerForIndex(index);
        if (center == null) {
          continue;
        }

        final distance = (center - targetCenter).abs();
        if (distance < closestDistance) {
          closestDistance = distance;
          closestIndex = index;
        }
      }

      return closestIndex;
    }

    final tabWidth = _tabWidth();
    if (tabWidth == null) {
      return widget.currentIndex;
    }

    final center = (_dragStartIndex * tabWidth) + (tabWidth / 2) + offset;
    final clampedCenter = center
        .clamp(tabWidth / 2, _gestureAreaWidth - (tabWidth / 2))
        .toDouble();
    final rawIndex = (clampedCenter / tabWidth).floor();
    if (rawIndex < 0) {
      return 0;
    }
    if (rawIndex >= widget.items.length) {
      return widget.items.length - 1;
    }
    return rawIndex;
  }

  double _targetOffsetForIndex(int index) {
    final startRect = _dragStartRect ?? _rectForIndex(_dragStartIndex);
    final targetRect = _rectForIndex(index);
    if (startRect != null && targetRect != null) {
      return targetRect.left - startRect.left;
    }

    final tabWidth = _tabWidth();
    if (tabWidth == null) {
      return 0.0;
    }
    return (index - _dragStartIndex) * tabWidth;
  }

  Duration _settleDurationForOffset(double targetOffset) {
    if (_gestureAreaWidth <= 0) {
      return const Duration(milliseconds: 320);
    }

    final distance =
        (targetOffset - _selectorAnimationController.value).abs() /
        _gestureAreaWidth;
    final durationMs = lerpDouble(
      220,
      360,
      distance.clamp(0.0, 1.0),
    )!;
    return Duration(milliseconds: durationMs.round());
  }

  void _onDragStart(LongPressStartDetails details) {
    final activeRect = _rectForIndex(widget.currentIndex);
    if (activeRect == null || !activeRect.contains(details.localPosition)) {
      return;
    }

    _selectorAnimationController.stop();
    _selectorAnimationController.value = 0.0;
    HapticFeedback.mediumImpact();
    setState(() {
      _isDragging = true;
      _dragOffsetX = 0.0;
      _draggingIndex = widget.currentIndex;
      _dragStartIndex = widget.currentIndex;
      _dragStartRect = activeRect;
      _dragStartX = details.localPosition.dx;
    });
  }

  void _onDragUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragging) {
      return;
    }

    final startRect = _dragStartRect ?? _rectForIndex(_dragStartIndex);
    final firstLeft = _leftForIndex(0);
    final lastLeft = _leftForIndex(widget.items.length - 1);
    final tabWidth = _tabWidth();
    if (tabWidth == null && startRect == null) {
      return;
    }

    final delta = details.localPosition.dx - _dragStartX;
    final minOffset = startRect != null && firstLeft != null
        ? firstLeft - startRect.left
        : -(_dragStartIndex * tabWidth!);
    final maxOffset = startRect != null && lastLeft != null
        ? lastLeft - startRect.left
        : (widget.items.length - 1 - _dragStartIndex) * tabWidth!;
    final boundedOffset = delta.clamp(minOffset, maxOffset).toDouble();
    final nextOffset = boundedOffset;
    final nextIndex = _indexForOffset(nextOffset);

    if ((_selectorAnimationController.value - nextOffset).abs() > 0.01) {
      _selectorAnimationController.value = nextOffset;
    }

    if (nextIndex != _draggingIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _draggingIndex = nextIndex;
      });
      _scheduleMeasurement();
    }
  }

  Future<void> _onDragEnd(LongPressEndDetails _) async {
    if (!_isDragging) {
      return;
    }

    final targetIndex = _draggingIndex;
    final targetOffset = _targetOffsetForIndex(targetIndex);

    try {
      await _selectorAnimationController.animateTo(
        targetOffset,
        duration: _settleDurationForOffset(targetOffset),
        curve: Curves.easeOutQuart,
      );
    } on TickerCanceled {
      return;
    }

    if (!mounted) {
      return;
    }

    widget.onTabChanged(targetIndex);
    if (!mounted) {
      return;
    }

    _selectorAnimationController.value = 0.0;
    setState(() {
      _isDragging = false;
      _dragOffsetX = 0.0;
      _dragStartRect = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectorRect = _rectForIndex(
      _isDragging ? _draggingIndex : widget.currentIndex,
    );
    final dragAnchorRect = _dragStartRect ?? _rectForIndex(widget.currentIndex);
    final selectorWidth = selectorRect?.width ?? 0.0;
    final selectorHeight = selectorRect?.height ?? 0.0;
    final selectorTop = selectorRect?.top ?? 0.0;
    final selectorLeft = !_isDragging
        ? (selectorRect?.left ?? 0.0)
        : ((dragAnchorRect?.left ?? 0.0) + _dragOffsetX).clamp(
            0.0,
            (_gestureAreaWidth - selectorWidth).clamp(0.0, double.infinity),
          );

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
            child: SizedBox(
              key: _gestureAreaKey,
              child: Stack(
                children: [
                  if (_isDragging &&
                      selectorRect != null &&
                      selectorWidth > 0 &&
                      selectorHeight > 0)
                    Positioned(
                      left: selectorLeft,
                      top: selectorTop,
                      width: selectorWidth,
                      height: selectorHeight,
                      child: IgnorePointer(
                        child: _buildSelector(),
                      ),
                    ),
                  if (!_isDragging &&
                      selectorRect != null &&
                      selectorWidth > 0 &&
                      selectorHeight > 0)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutQuart,
                      left: selectorLeft,
                      top: selectorTop,
                      width: selectorWidth,
                      height: selectorHeight,
                      child: IgnorePointer(
                        child: _buildSelector(),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(widget.items.length, (index) {
                      return Listener(
                        onPointerUp: (_) {
                          if (!_isDragging && index != widget.currentIndex) {
                            widget.onTabChanged(index);
                            HapticFeedback.selectionClick();
                          }
                        },
                        child: _buildNavItem(index, widget.items[index]),
                      );
                    }),
                  ),
                  Positioned.fill(
                    child: RawGestureDetector(
                      behavior: HitTestBehavior.translucent,
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
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
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
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              )
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
    final selectedIndex = _isDragging ? _draggingIndex : widget.currentIndex;
    final isSelected = selectedIndex == index;

    return Container(
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
    );
  }
}
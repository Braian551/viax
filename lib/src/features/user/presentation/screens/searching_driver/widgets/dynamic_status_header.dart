import 'dart:async';

import 'package:flutter/material.dart';

@immutable
class FlowHeaderMessage {
  final String title;
  final String subtitle;
  final Duration duration;

  const FlowHeaderMessage({
    required this.title,
    required this.subtitle,
    this.duration = const Duration(seconds: 4),
  });
}

class DynamicStatusHeader extends StatefulWidget {
  final List<FlowHeaderMessage> messages;
  final int? currentIndex;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final CrossAxisAlignment crossAxisAlignment;

  const DynamicStatusHeader({
    super.key,
    required this.messages,
    this.currentIndex,
    this.titleStyle,
    this.subtitleStyle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  State<DynamicStatusHeader> createState() => _DynamicStatusHeaderState();
}

class _DynamicStatusHeaderState extends State<DynamicStatusHeader> {
  Timer? _timer;
  int _localIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant DynamicStatusHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex ||
        widget.messages.length != oldWidget.messages.length) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (widget.currentIndex != null || widget.messages.length <= 1) {
      return;
    }
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    if (!mounted || widget.messages.length <= 1) {
      return;
    }

    final currentMessage = widget.messages[_safeIndex(_localIndex)];
    _timer = Timer(currentMessage.duration, () {
      if (!mounted) return;
      setState(() {
        _localIndex = (_localIndex + 1) % widget.messages.length;
      });
      _scheduleNextTick();
    });
  }

  int _safeIndex(int value) {
    if (widget.messages.isEmpty) return 0;
    return ((value % widget.messages.length) + widget.messages.length) %
        widget.messages.length;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeIndex = _safeIndex(widget.currentIndex ?? _localIndex);
    final message = widget.messages[activeIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey(
          'header_${message.title}_${message.subtitle}_$activeIndex',
        ),
        crossAxisAlignment: widget.crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: widget.titleStyle,
          ),
          const SizedBox(height: 4),
          Text(
            message.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: widget.subtitleStyle,
          ),
        ],
      ),
    );
  }
}

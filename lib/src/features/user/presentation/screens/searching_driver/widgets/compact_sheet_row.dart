import 'package:flutter/material.dart';

import 'dynamic_status_header.dart';

class CompactSheetRow extends StatelessWidget {
  final Widget leading;
  final Widget trailing;
  final List<FlowHeaderMessage> messages;
  final int currentMessageIndex;

  const CompactSheetRow({
    super.key,
    required this.leading,
    required this.trailing,
    required this.messages,
    required this.currentMessageIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: isNarrow ? 82 : 72),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: leading),
          SizedBox(width: isNarrow ? 10 : 12),
          Expanded(
            child: DynamicStatusHeader(
              messages: messages,
              currentIndex: currentMessageIndex,
              titleStyle: theme.textTheme.titleLarge?.copyWith(
                fontSize: isNarrow ? 17 : 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                height: 1.15,
              ),
              subtitleStyle: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isNarrow ? 12 : 13,
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                height: 1.25,
              ),
            ),
          ),
          SizedBox(width: isNarrow ? 10 : 12),
          Padding(padding: const EdgeInsets.only(top: 2), child: trailing),
        ],
      ),
    );
  }
}

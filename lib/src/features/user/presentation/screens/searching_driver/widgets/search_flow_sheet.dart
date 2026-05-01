import 'package:flutter/material.dart';

import '../searching_driver_state.dart';
import 'compact_sheet_row.dart';
import 'dynamic_status_header.dart';
import 'expanded_sheet_content.dart';

class SearchFlowSheet extends StatefulWidget {
  final SearchingDriverState state;
  final DraggableScrollableController? sheetController;
  final List<FlowHeaderMessage> headerMessages;
  final Widget leading;
  final Widget trailing;
  final String originLabel;
  final String destinationLabel;
  final String vehicleLabel;
  final String? priceLabel;
  final String paymentLabel;
  final List<String> serviceFeatures;
  final VoidCallback onCancel;
  final VoidCallback? onFareSelected;
  final ValueChanged<double>? onSheetSizeChanged;

  const SearchFlowSheet({
    super.key,
    required this.state,
    required this.headerMessages,
    required this.leading,
    required this.trailing,
    required this.originLabel,
    required this.destinationLabel,
    required this.vehicleLabel,
    required this.paymentLabel,
    required this.serviceFeatures,
    required this.onCancel,
    this.sheetController,
    this.priceLabel,
    this.onFareSelected,
    this.onSheetSizeChanged,
  });

  @override
  State<SearchFlowSheet> createState() => _SearchFlowSheetState();
}

class _SearchFlowSheetState extends State<SearchFlowSheet> {
  static const double _collapsedSize = 0.12;
  static const double _compactSize = 0.28;
  static const double _expandedSize = 0.85;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isNarrow = MediaQuery.sizeOf(context).width < 360;
    final isHandleOnly = widget.state.sheetSize <= 0.16;
    final isExpanded = widget.state.sheetSize >= 0.72;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        widget.onSheetSizeChanged?.call(notification.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        controller: widget.sheetController,
        initialChildSize: _compactSize,
        minChildSize: _collapsedSize,
        maxChildSize: _expandedSize,
        snap: true,
        snapSizes: const [_collapsedSize, _compactSize, _expandedSize],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withValues(alpha: 0.98)
                  : colorScheme.surface.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 14 : 18,
                0,
                isNarrow ? 14 : 18,
                18 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 14),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(
                          alpha: isDark ? 0.9 : 0.72,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (!isHandleOnly) ...[
                    CompactSheetRow(
                      leading: widget.leading,
                      trailing: widget.trailing,
                      messages: widget.headerMessages,
                      currentMessageIndex: widget.state.dynamicMessageIndex,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      child: isExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: ExpandedSheetContent(
                                state: widget.state,
                                originLabel: widget.originLabel,
                                destinationLabel: widget.destinationLabel,
                                vehicleLabel: widget.vehicleLabel,
                                priceLabel: widget.priceLabel,
                                paymentLabel: widget.paymentLabel,
                                serviceFeatures: widget.serviceFeatures,
                                onCancel: widget.onCancel,
                                onFareSelected: widget.onFareSelected,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (!isExpanded) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(
                            alpha: isDark ? 0.16 : 0.06,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swipe_up_rounded,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Arrastra para ver precio, ruta y opciones de viaje.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

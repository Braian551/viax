import 'package:flutter/material.dart';
import '../../../../../../global/models/simple_location.dart';
import '../../../../../../theme/app_colors.dart';
import 'waypoint_tiles.dart';

class WaypointsList extends StatelessWidget {
  final SimpleLocation? origin;
  final SimpleLocation? destination;
  final List<SimpleLocation?> stops;
  final bool isDark;
  final bool isGettingLocation;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;
  final void Function(int index) onStopTap;
  final void Function(int index) onRemoveStop;

  const WaypointsList({
    super.key,
    required this.origin,
    required this.destination,
    required this.stops,
    required this.isDark,
    required this.isGettingLocation,
    required this.onReorder,
    required this.onOriginTap,
    required this.onDestinationTap,
    required this.onStopTap,
    required this.onRemoveStop,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = 1 + stops.length + 1;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalItems,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        shadowColor: AppColors.primary.withOpacity(0.3),
        child: child,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return WaypointTile(
            tileKey: const ValueKey('origin'),
            index: index,
            label: 'Origen',
            value: origin,
            placeholder: '¿Desde dónde?',
            icon: Icons.my_location_rounded,
            iconColor: AppColors.primary,
            isDark: isDark,
            isLoading: isGettingLocation,
            onTap: onOriginTap,
            showDivider: true,
          );
        }

        if (index == totalItems - 1) {
          return WaypointTile(
            tileKey: const ValueKey('destination'),
            index: index,
            label: 'Destino',
            value: destination,
            placeholder: '¿A dónde vamos?',
            icon: Icons.flag_rounded,
            iconColor: AppColors.primaryDark,
            isDark: isDark,
            isLoading: false,
            onTap: onDestinationTap,
            showDivider: false,
          );
        }

        final stopIndex = index - 1;
        return StopTile(
          tileKey: ValueKey('stop_$stopIndex'),
          index: index,
          stopIndex: stopIndex,
          stop: stops[stopIndex],
          isDark: isDark,
          onTap: () => onStopTap(stopIndex),
          onRemove: () => onRemoveStop(stopIndex),
          showDivider: true,
        );
      },
    );
  }
}
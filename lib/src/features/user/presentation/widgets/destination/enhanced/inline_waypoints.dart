import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../../global/models/simple_location.dart';
import '../../../../../../global/services/location_suggestion_service.dart';
import '../../../../../../theme/app_colors.dart';
import '../inline_suggestions.dart';

class InlineWaypoints extends StatelessWidget {
  final TextEditingController originController;
  final TextEditingController destinationController;
  final FocusNode originFocusNode;
  final FocusNode destinationFocusNode;
  final LocationSuggestionService suggestionService;
  final LatLng? userLocation;
  final bool isDark;
  final bool hasOriginSelected;
  final bool hasDestinationSelected;
  final ValueChanged<SimpleLocation> onOriginSelected;
  final ValueChanged<SimpleLocation> onDestinationSelected;
  final VoidCallback onOriginChanged;
  final VoidCallback onDestinationChanged;
  final Future<String?> Function(LatLng point) reverseGeocode;
  final VoidCallback openOriginMap;
  final VoidCallback openDestinationMap;

  const InlineWaypoints({
    super.key,
    required this.originController,
    required this.destinationController,
    required this.originFocusNode,
    required this.destinationFocusNode,
    required this.suggestionService,
    required this.userLocation,
    required this.isDark,
    required this.hasOriginSelected,
    required this.hasDestinationSelected,
    required this.onOriginSelected,
    required this.onDestinationSelected,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.reverseGeocode,
    required this.openOriginMap,
    required this.openDestinationMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: InlineSuggestions(
            controller: originController,
            focusNode: originFocusNode,
            suggestionService: suggestionService,
            userLocation: userLocation,
            isOrigin: true,
            isDark: isDark,
            accentColor: AppColors.primary,
            placeholder: 'Origen - ¿Desde dónde?',
            hasLocationSelected: hasOriginSelected,
            onLocationSelected: onOriginSelected,
            onTextChanged: onOriginChanged,
            onUseCurrentLocation: userLocation == null
                ? null
                : () async {
                    final address = await reverseGeocode(userLocation!);
                    onOriginSelected(
                      SimpleLocation(
                        latitude: userLocation!.latitude,
                        longitude: userLocation!.longitude,
                        address: address ?? 'Mi ubicación',
                      ),
                    );
                  },
            onOpenMap: openOriginMap,
          ),
        ),
        const _WaypointDivider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: InlineSuggestions(
            controller: destinationController,
            focusNode: destinationFocusNode,
            suggestionService: suggestionService,
            userLocation: userLocation,
            isOrigin: false,
            isDark: isDark,
            accentColor: AppColors.primaryDark,
            placeholder: 'Destino - ¿A dónde?',
            hasLocationSelected: hasDestinationSelected,
            onLocationSelected: onDestinationSelected,
            onTextChanged: onDestinationChanged,
            onOpenMap: openDestinationMap,
          ),
        ),
      ],
    );
  }
}

class _WaypointDivider extends StatelessWidget {
  const _WaypointDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.grey.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

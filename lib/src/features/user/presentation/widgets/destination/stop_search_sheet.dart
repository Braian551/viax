import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../global/models/simple_location.dart';
import '../../../../../global/services/location_suggestion_service.dart';
import '../../../../../theme/app_colors.dart';
import 'location_search_sheet.dart';

/// Mostrar el sheet de búsqueda de parada
/// Ahora reutiliza [LocationSearchSheet] para mantener consistencia de diseño
Future<SimpleLocation?> showStopSearchSheet({
  required BuildContext context,
  required int stopNumber,
  SimpleLocation? currentValue,
  LatLng? userLocation,
  required LocationSuggestionService suggestionService,
}) {
  return showLocationSearchSheet(
    context: context,
    title: 'Parada $stopNumber',
    icon: Icons.flag_rounded,
    accentColor: AppColors.accent,
    currentValue: currentValue,
    userLocation: userLocation,
    suggestionService: suggestionService,
    isOrigin: false,
  );
}

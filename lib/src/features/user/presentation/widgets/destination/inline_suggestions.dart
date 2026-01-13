import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../global/models/simple_location.dart';
import '../../../../../global/services/location_suggestion_service.dart';
import '../../../../../theme/app_colors.dart';

/// Widget de sugerencias inline que aparece debajo del input
/// Solo se muestra cuando hay texto escrito
class InlineSuggestions extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LocationSuggestionService suggestionService;
  final LatLng? userLocation;
  final bool isOrigin;
  final bool isDark;
  final Color accentColor;
  final String placeholder;
  final bool hasLocationSelected;
  final Function(SimpleLocation) onLocationSelected;
  final VoidCallback onTextChanged;
  final VoidCallback? onUseCurrentLocation;
  final VoidCallback? onOpenMap;
  final String? heroTag;

  const InlineSuggestions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.suggestionService,
    this.userLocation,
    this.isOrigin = false,
    required this.isDark,
    required this.accentColor,
    required this.placeholder,
    required this.hasLocationSelected,
    required this.onLocationSelected,
    required this.onTextChanged,
    this.onUseCurrentLocation,
    this.onOpenMap,
    this.heroTag,
  });

  @override
  State<InlineSuggestions> createState() => _InlineSuggestionsState();
}

class _InlineSuggestionsState extends State<InlineSuggestions> {
  List<SimpleLocation> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    // Strict focus check: Don't search/update if user isn't focused
    if (!widget.focusNode.hasFocus) return;

    // Notificar que el texto cambió (marca como no seleccionado)
    widget.onTextChanged();

    _debounce?.cancel();

    final query = widget.controller.text.trim();
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchSuggestions(query);
    });
  }

  Future<void> _searchSuggestions(String query) async {
    setState(() => _isLoading = true);

    try {
      final results = await widget.suggestionService.searchSuggestions(
        query: query,
        limit: 5,
        localFirst: true,
      );

      if (mounted) {
        setState(() => _suggestions = results);
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectLocation(SimpleLocation location) {
    HapticFeedback.selectionClick();
    widget.controller.text = location.address;
    widget.focusNode.unfocus();
    widget.onLocationSelected(location);
    setState(() => _suggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo de búsqueda con diseño glass
        heroWrapper(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppColors.darkCard
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.focusNode.hasFocus
                      ? widget.accentColor
                      : widget.isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.2),
                  width: widget.focusNode.hasFocus ? 1.5 : 1,
                ),
                boxShadow: widget.focusNode.hasFocus
                    ? [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.grey[900],
                  letterSpacing: -0.2,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF5F7FA), // Subtle fill for contrast
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(
                    color: widget.isDark ? Colors.white38 : Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: ShapeDecoration(
                        color: widget.accentColor.withValues(alpha: 0.12),
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(20), // Squircle
                        ),
                      ),
                      child: Icon(
                        widget.isOrigin
                            ? Icons.circle_outlined
                            : Icons.search_rounded,
                        color: widget.accentColor,
                        size: 16,
                      ),
                    ),
                  ),
                  suffixIcon: widget.controller.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onTextChanged();
                            widget.controller.clear();
                            setState(() => _suggestions = []);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: ShapeDecoration(
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                shape: ContinuousRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: widget.isDark
                                    ? Colors.white54
                                    : Colors.grey[600],
                                size: 14,
                              ),
                            ),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none, // Remove inner border
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),



        // Lugares guardados (solo cuando no hay texto escrito y tiene focus)
        if (false && widget.focusNode.hasFocus && // Temporarily disabled
            widget.controller.text.isEmpty &&
            !widget.hasLocationSelected)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Expanded(
                  child: _SavedPlaceChip(
                    icon: Icons.home_rounded,
                    label: 'Casa',
                    isDark: widget.isDark,
                    onTap: () {
                      // TODO: Cargar ubicación casa
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SavedPlaceChip(
                    icon: Icons.work_rounded,
                    label: 'Trabajo',
                    isDark: widget.isDark,
                    onTap: () {
                      // TODO: Cargar ubicación trabajo
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SavedPlaceChip(
                    icon: Icons.star_rounded,
                    label: 'Favoritos',
                    isDark: widget.isDark,
                    onTap: () {
                      // TODO: Mostrar favoritos
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              ],
            ),
          ),

        // Loading Shimmer
        if (_isLoading && widget.focusNode.hasFocus)
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Shimmer.fromColors(
              baseColor: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300]!,
              highlightColor: widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100]!,
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 150,
                                height: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        // Sugerencias de búsqueda (cuando hay texto escrito)
        if (_suggestions.isNotEmpty &&
            !_isLoading &&
            widget.focusNode.hasFocus &&
            !widget.hasLocationSelected)
          Container(
            margin: const EdgeInsets.only(top: 10),
            constraints: const BoxConstraints(
              maxHeight: 280, // Altura máxima para scroll
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDark ? 0.3 : 0.1,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.85),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 68),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final location = _suggestions[index];
                      return _SuggestionTile(
                        location: location,
                        isDark: widget.isDark,
                        onTap: () => _selectLocation(location),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

        // Opción de ubicación actual (solo para origen y cuando tiene focus)
        if (widget.focusNode.hasFocus &&
            widget.isOrigin &&
            widget.onUseCurrentLocation != null &&
            !widget.hasLocationSelected &&
            _suggestions.isEmpty &&
            !_isLoading &&
            widget.controller.text.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _QuickOptionTile(
              icon: Icons.my_location_rounded,
              title: 'Usar ubicación actual',
              color: AppColors.primary,
              isDark: widget.isDark,
              onTap: widget.onUseCurrentLocation!,
            ),
          ),

        // Opción de seleccionar en el mapa (SIEMPRE visible cuando tiene focus)
        if (widget.focusNode.hasFocus && 
            widget.onOpenMap != null &&
            !widget.hasLocationSelected)
          Padding(
            padding: EdgeInsets.only(
              top: widget.isOrigin &&
                      widget.onUseCurrentLocation != null &&
                      _suggestions.isEmpty &&
                      !_isLoading &&
                      widget.controller.text.isEmpty
                  ? 8
                  : 12,
            ),
            child: _QuickOptionTile(
              icon: Icons.map_outlined,
              title: 'Seleccionar en el mapa',
              color: widget.accentColor,
              isDark: widget.isDark,
              onTap: widget.onOpenMap!,
            ),
          ),
      ],
    );
  }
  Widget heroWrapper({required Widget child}) {
    if (widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
    }
    return child;
  }
}

class _SavedPlaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SavedPlaceChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final SimpleLocation location;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.location,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Usar las propiedades mejoradas de SimpleLocation
    final name = location.displayName;
    final subtitle = location.displaySubtitle;
    final distance = location.formattedDistance;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  _getIconForPlaceType(location.placeType),
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[900],
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Mostrar distancia si está disponible
              if (distance.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    distance,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                )
              else
                Icon(
                  Icons.north_west_rounded,
                  size: 16,
                  color: isDark ? Colors.white24 : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Icono basado en el tipo de lugar
  IconData _getIconForPlaceType(String? placeType) {
    switch (placeType) {
      case 'poi':
        return Icons.place_rounded;
      case 'address':
        return Icons.home_rounded;
      case 'place':
        return Icons.location_city_rounded;
      case 'neighborhood':
        return Icons.apartment_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

}


class _QuickOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickOptionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[800],
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

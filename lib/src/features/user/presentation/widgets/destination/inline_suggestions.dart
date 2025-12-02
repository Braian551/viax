import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
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
  final Function(SimpleLocation) onLocationSelected;
  final VoidCallback? onUseCurrentLocation;
  final VoidCallback? onOpenMap;

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
    required this.onLocationSelected,
    this.onUseCurrentLocation,
    this.onOpenMap,
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.focusNode.hasFocus
                  ? [
                      widget.accentColor.withOpacity(0.08),
                      widget.accentColor.withOpacity(0.04),
                    ]
                  : [
                      widget.isDark 
                          ? Colors.white.withOpacity(0.08) 
                          : Colors.grey.withOpacity(0.08),
                      widget.isDark 
                          ? Colors.white.withOpacity(0.04) 
                          : Colors.grey.withOpacity(0.04),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.focusNode.hasFocus
                  ? widget.accentColor.withOpacity(0.4)
                  : widget.isDark 
                      ? Colors.white.withOpacity(0.08) 
                      : Colors.black.withOpacity(0.05),
              width: widget.focusNode.hasFocus ? 1.5 : 1,
            ),
            boxShadow: widget.focusNode.hasFocus
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white : Colors.grey[900],
              letterSpacing: -0.2,
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: TextStyle(
                color: widget.isDark ? Colors.white38 : Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isOrigin ? Icons.circle_outlined : Icons.search_rounded,
                    color: widget.accentColor,
                    size: 16,
                  ),
                ),
              ),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.controller.clear();
                        setState(() => _suggestions = []);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: widget.isDark 
                                ? Colors.white.withOpacity(0.1) 
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: widget.isDark ? Colors.white54 : Colors.grey[600],
                            size: 16,
                          ),
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, 
                vertical: 16,
              ),
            ),
          ),
        ),

        // Lugares guardados (siempre visibles cuando hay focus)
        if (widget.focusNode.hasFocus)
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
        
        // Loading
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                ),
              ),
            ),
          ),
        
        // Sugerencias (después de lugares guardados)
        if (_suggestions.isNotEmpty && !_isLoading)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: widget.isDark 
                      ? Colors.black.withOpacity(0.5) 
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.black.withOpacity(0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _suggestions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final location = entry.value;
                    final isLast = index == _suggestions.length - 1;
                    
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SuggestionTile(
                          location: location,
                          isDark: widget.isDark,
                          onTap: () => _selectLocation(location),
                        ),
                        if (!isLast)
                          Container(
                            height: 1,
                            margin: const EdgeInsets.only(left: 68),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.isDark 
                                      ? Colors.white.withOpacity(0.08) 
                                      : Colors.grey.withOpacity(0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        
        // Opciones rápidas cuando no hay texto ni sugerencias
        if (_suggestions.isEmpty && 
            !_isLoading && 
            widget.controller.text.isEmpty &&
            widget.focusNode.hasFocus)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Ubicación actual (solo origen)
              if (widget.isOrigin && widget.onUseCurrentLocation != null)
                _QuickOptionTile(
                  icon: Icons.my_location_rounded,
                  title: 'Usar ubicación actual',
                  color: AppColors.primary,
                  isDark: widget.isDark,
                  onTap: widget.onUseCurrentLocation!,
                ),
              if (widget.onOpenMap != null) ...[
                const SizedBox(height: 8),
                _QuickOptionTile(
                  icon: Icons.map_outlined,
                  title: 'Seleccionar en el mapa',
                  color: widget.accentColor,
                  isDark: widget.isDark,
                  onTap: widget.onOpenMap!,
                ),
              ],
            ],
          ),
      ],
    );
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
                  ? Colors.white.withOpacity(0.08) 
                  : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.05),
              ),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
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
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon, 
                    size: 14, 
                    color: AppColors.primary,
                  ),
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
    final info = LocationSuggestionService.parseAddress(location.address);

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
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.location_on_rounded,
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
                      info.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[900],
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (info.subtitle.isNotEmpty)
                      Text(
                        info.subtitle,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.12),
                  color.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
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
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_forward_rounded, color: color, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

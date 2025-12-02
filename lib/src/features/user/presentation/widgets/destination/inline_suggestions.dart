import 'dart:async';
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
        // Campo de búsqueda
        Container(
          decoration: BoxDecoration(
            color: widget.isDark 
                ? Colors.white.withOpacity(0.06) 
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
            border: widget.focusNode.hasFocus
                ? Border.all(color: widget.accentColor.withOpacity(0.4), width: 1.5)
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: TextStyle(
              fontSize: 15,
              color: widget.isDark ? Colors.white : Colors.grey[900],
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: TextStyle(
                color: widget.isDark ? Colors.white38 : Colors.grey[500],
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: widget.accentColor.withOpacity(0.7),
                size: 20,
              ),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        setState(() => _suggestions = []);
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: widget.isDark ? Colors.white38 : Colors.grey[500],
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, 
                vertical: 14,
              ),
            ),
          ),
        ),

        // Lugares guardados (siempre visibles cuando hay focus)
        if (widget.focusNode.hasFocus)
          Padding(
            padding: const EdgeInsets.only(top: 12),
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
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: widget.isDark 
                  ? Colors.grey[850] 
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
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
                        Divider(
                          height: 1,
                          indent: 52,
                          color: widget.isDark 
                              ? Colors.white.withOpacity(0.06) 
                              : Colors.grey.withOpacity(0.1),
                        ),
                    ],
                  );
                }).toList(),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.06) 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.grey[900],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../global/models/simple_location.dart';
import '../../../../../global/services/location_suggestion_service.dart';
import '../../../../../theme/app_colors.dart';
import '../map_location_picker_sheet.dart';

/// Bottom sheet con drag para buscar paradas
class StopSearchSheet extends StatefulWidget {
  final int stopNumber;
  final SimpleLocation? currentValue;
  final LatLng? userLocation;
  final LocationSuggestionService suggestionService;

  const StopSearchSheet({
    super.key,
    required this.stopNumber,
    this.currentValue,
    this.userLocation,
    required this.suggestionService,
  });

  @override
  State<StopSearchSheet> createState() => _StopSearchSheetState();
}

class _StopSearchSheetState extends State<StopSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SimpleLocation> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchSuggestions(query.trim());
    });
  }

  Future<void> _searchSuggestions(String query) async {
    setState(() => _isLoading = true);

    try {
      final results = await widget.suggestionService.searchSuggestions(
        query: query,
        limit: 8,
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
    Navigator.pop(context, location);
  }

  Future<void> _openMapPicker() async {
    final result = await showMapLocationPicker(
      context: context,
      initialLocation: widget.currentValue,
      userLocation: widget.userLocation,
      title: 'Parada ${widget.stopNumber}',
      accentColor: AppColors.accent,
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle para drag
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.stopNumber}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Parada ${widget.stopNumber}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openMapPicker,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.08) 
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.map_outlined,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                ? Colors.white.withValues(alpha: 0.06) 
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar dirección...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _suggestions = []);
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white38 : Colors.grey[500],
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
          ),
          const SizedBox(height: 12),
          // Contenido
          Expanded(child: _buildContent(isDark)),
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_suggestions.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 52,
          color: isDark 
            ? Colors.white.withValues(alpha: 0.06) 
            : Colors.grey.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final location = _suggestions[index];
          return _buildSuggestionTile(location, isDark);
        },
      );
    }

    // Estado vacío
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickOption(
            icon: Icons.map_outlined,
            title: 'Seleccionar en el mapa',
            subtitle: 'Toca para elegir ubicación',
            color: AppColors.accent,
            isDark: isDark,
            onTap: _openMapPicker,
          ),
          const SizedBox(height: 24),
          Text(
            'Escribe para buscar',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa una dirección para ver sugerencias',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(SimpleLocation location, bool isDark) {
    final info = LocationSuggestionService.parseAddress(location.address);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectLocation(location),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.06) 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  size: 22,
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
                        fontSize: 15,
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
                          fontSize: 13,
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
                size: 18,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostrar el sheet de búsqueda de parada
Future<SimpleLocation?> showStopSearchSheet({
  required BuildContext context,
  required int stopNumber,
  SimpleLocation? currentValue,
  LatLng? userLocation,
  required LocationSuggestionService suggestionService,
}) {
  return showModalBottomSheet<SimpleLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StopSearchSheet(
      stopNumber: stopNumber,
      currentValue: currentValue,
      userLocation: userLocation,
      suggestionService: suggestionService,
    ),
  );
}

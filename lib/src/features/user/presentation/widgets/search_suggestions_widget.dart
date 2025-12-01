import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';

/// Item de historial de búsqueda
class SearchHistoryItem {
  final String title;
  final String subtitle;
  final SimpleLocation? location;
  final IconData icon;
  final DateTime timestamp;

  const SearchHistoryItem({
    required this.title,
    required this.subtitle,
    this.location,
    this.icon = Icons.history_rounded,
    required this.timestamp,
  });
}

/// Widget de sugerencia de ubicación animado
class LocationSuggestionTile extends StatefulWidget {
  final SimpleLocation location;
  final VoidCallback onTap;
  final int index;
  final bool isHistory;
  final IconData? customIcon;
  final Color? iconColor;

  const LocationSuggestionTile({
    super.key,
    required this.location,
    required this.onTap,
    this.index = 0,
    this.isHistory = false,
    this.customIcon,
    this.iconColor,
  });

  @override
  State<LocationSuggestionTile> createState() => _LocationSuggestionTileState();
}

class _LocationSuggestionTileState extends State<LocationSuggestionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300 + (widget.index * 50)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Delay basado en el índice para efecto escalonado
    Future.delayed(Duration(milliseconds: widget.index * 30), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getMainText(String address) {
    final parts = address.split(',');
    return parts.isNotEmpty ? parts.first.trim() : address;
  }

  String _getSecondaryText(String address) {
    final parts = address.split(',');
    if (parts.length > 1) {
      return parts.sublist(1).take(2).join(',').trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainText = _getMainText(widget.location.address);
    final secondaryText = _getSecondaryText(widget.location.address);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onTap();
                },
                borderRadius: BorderRadius.circular(16),
                splashColor: AppColors.primary.withOpacity(0.1),
                highlightColor: AppColors.primary.withOpacity(0.05),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (widget.iconColor ?? const Color(0xFFFF6B35))
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.customIcon ??
                              (widget.isHistory
                                  ? Icons.history_rounded
                                  : Icons.location_on_rounded),
                          color: widget.iconColor ?? AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mainText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (secondaryText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                secondaryText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.grey[500],
                                  letterSpacing: -0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.north_west_rounded,
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de sugerencias de búsqueda con animaciones
class SearchSuggestionsList extends StatelessWidget {
  final List<SimpleLocation> suggestions;
  final List<SearchHistoryItem> history;
  final bool isLoading;
  final Function(SimpleLocation) onSuggestionTap;
  final bool showHistory;

  const SearchSuggestionsList({
    super.key,
    required this.suggestions,
    this.history = const [],
    this.isLoading = false,
    required this.onSuggestionTap,
    this.showHistory = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Buscando lugares...',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Si hay sugerencias, mostrarlas
    if (suggestions.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return LocationSuggestionTile(
            location: suggestions[index],
            index: index,
            onTap: () => onSuggestionTap(suggestions[index]),
          );
        },
      );
    }

    // Si hay historial y no hay sugerencias, mostrar historial
    if (showHistory && history.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(),
        itemCount: history.length + 1, // +1 para el header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Búsquedas recientes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            );
          }

          final historyItem = history[index - 1];
          if (historyItem.location != null) {
            return LocationSuggestionTile(
              location: historyItem.location!,
              index: index,
              isHistory: true,
              customIcon: historyItem.icon,
              onTap: () => onSuggestionTap(historyItem.location!),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }

    // Estado vacío
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 48,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Busca una dirección',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe el nombre de una calle, lugar o dirección',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class VehicleSearchableSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T)? searchText;
  final Future<List<T>> Function(String query)? onSearch;
  final Duration searchDebounce;
  final void Function(T) onSelected;
  final String searchHint;
  final IconData headerIcon;
  final String? selectedLabel;
  final IconData itemIcon;

  const VehicleSearchableSheet({
    super.key,
    required this.title,
    required this.items,
    required this.itemLabel,
    this.searchText,
    this.onSearch,
    this.searchDebounce = const Duration(milliseconds: 320),
    required this.onSelected,
    this.searchHint = 'Buscar...',
    this.headerIcon = Icons.directions_car_rounded,
    this.selectedLabel,
    this.itemIcon = Icons.directions_car_filled_outlined,
  });

  @override
  State<VehicleSearchableSheet<T>> createState() => _VehicleSearchableSheetState<T>();
}

class _VehicleSearchableSheetState<T> extends State<VehicleSearchableSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];
  Timer? _searchDebounceTimer;
  bool _isSearching = false;
  int _searchSequence = 0;

  String _normalizeSearchText(String value) {
    final lower = value.toLowerCase();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesQuery(String candidate, String query) {
    final normalizedCandidate = _normalizeSearchText(candidate);
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return true;

    if (normalizedCandidate.contains(normalizedQuery)) {
      return true;
    }

    final compactCandidate = normalizedCandidate.replaceAll(' ', '');
    final compactQuery = normalizedQuery.replaceAll(' ', '');
    if (compactQuery.isNotEmpty && compactCandidate.contains(compactQuery)) {
      return true;
    }

    final tokens = normalizedQuery.split(' ').where((token) => token.isNotEmpty);
    return tokens.every((token) =>
        normalizedCandidate.contains(token) || compactCandidate.contains(token.replaceAll(' ', '')));
  }

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void didUpdateWidget(covariant VehicleSearchableSheet<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _applyFilter(_searchController.text);
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter(String query) {
    final normalized = query.trim();
    if (widget.onSearch != null) {
      _searchDebounceTimer?.cancel();

      if (normalized.isEmpty) {
        setState(() {
          _isSearching = false;
          _filteredItems = widget.items;
        });
        return;
      }

      setState(() {
        _filteredItems = widget.items
            .where((item) {
              final searchBase = widget.searchText?.call(item) ?? widget.itemLabel(item);
              return _matchesQuery(searchBase, normalized);
            })
            .toList();
        _isSearching = true;
      });

      _searchDebounceTimer = Timer(widget.searchDebounce, () {
        _performRemoteSearch(normalized);
      });
      return;
    }

    setState(() {
      if (normalized.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) {
              final searchBase = widget.searchText?.call(item) ?? widget.itemLabel(item);
              return _matchesQuery(searchBase, normalized);
            })
            .toList();
      }
    });
  }

  Future<void> _performRemoteSearch(String query) async {
    final onSearch = widget.onSearch;
    if (onSearch == null || query.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      return;
    }

    final int requestId = ++_searchSequence;
    try {
      final result = await onSearch(query);
      if (!mounted || requestId != _searchSequence) return;
      setState(() {
        _filteredItems = result;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchSequence) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground.withValues(alpha: 0.92)
                : AppColors.lightBackground.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 18),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.headerIcon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _applyFilter,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(
                        child: _isSearching
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Buscando coincidencias...',
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600),
                                  ),
                                ],
                              )
                            : Text(
                                'No se encontraron resultados',
                                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                              ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final label = widget.itemLabel(item);
                          final isSelected =
                              widget.selectedLabel != null && widget.selectedLabel!.toLowerCase() == label.toLowerCase();

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                            leading: Icon(
                              isSelected ? Icons.check_circle_rounded : widget.itemIcon,
                              size: 20,
                              color: isSelected ? AppColors.primary : (isDark ? Colors.white54 : Colors.black45),
                            ),
                            title: Text(
                              label,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                            onTap: () {
                              widget.onSelected(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

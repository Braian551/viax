import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class SearchableDropdownSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T) onSelected;
  final String searchHint;

  const SearchableDropdownSheet({
    super.key,
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    this.searchHint = 'Buscar...',
  });

  @override
  State<SearchableDropdownSheet<T>> createState() => _SearchableDropdownSheetState<T>();
}

class _SearchableDropdownSheetState<T> extends State<SearchableDropdownSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => widget.itemLabel(item).toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Slightly taller
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          
          // Header with Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: Row(
              children: [
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(
                     color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(
                        color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                     )
                   ),
                   child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 24),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                 ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterItems,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? AppColors.darkDivider : Colors.grey.shade200),

          // List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No se encontraron resultados',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onSelected(item);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined, 
                                  size: 20, 
                                  color: Colors.grey.shade400
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    widget.itemLabel(item),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded, 
                                  size: 14, 
                                  color: Colors.grey.shade300
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

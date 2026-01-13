import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../../theme/app_colors.dart';
import '../../../domain/models/company_vehicle_models.dart';

class CompanyPickerSheet extends StatefulWidget {
  const CompanyPickerSheet({
    super.key,
    required this.companies,
    required this.selectedCompanyId,
    required this.onCompanySelected,
    required this.isDark,
  });

  final List<CompanyVehicleOption> companies;
  final int? selectedCompanyId;
  final ValueChanged<int> onCompanySelected;
  final bool isDark;

  @override
  State<CompanyPickerSheet> createState() => _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends State<CompanyPickerSheet> {
  late List<CompanyVehicleOption> _filteredCompanies;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filteredCompanies = widget.companies;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCompanies = widget.companies.where((company) {
        return company.nombre.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Draggable Sheet for better "Drag" experience
    return DraggableScrollableSheet(
      initialChildSize: 0.75, // Altura inicial (75% de la pantalla)
      minChildSize: 0.5,      // Altura mínima (50%)
      maxChildSize: 0.95,     // Altura máxima (95%)
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark 
                ? const Color(0xFF1A1A1A).withValues(alpha: 0.85) 
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.business_rounded, 
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Elige la empresa',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: widget.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.isDark 
                            ? Colors.white.withValues(alpha: 0.08) 
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _searchFocusNode.hasFocus 
                              ? AppColors.primary.withValues(alpha: 0.5) 
                              : (widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        onTap: () {
                          // Ensure focus causes build to update border
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre...',
                          hintStyle: TextStyle(
                            color: widget.isDark ? Colors.white38 : Colors.grey[500],
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: _searchFocusNode.hasFocus 
                                ? AppColors.primary
                                : (widget.isDark ? Colors.white54 : Colors.grey[500]),
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty 
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  // remove focus
                                  _searchFocusNode.unfocus();
                                  setState(() {});
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  color: widget.isDark ? Colors.white54 : Colors.grey[500],
                                  size: 20,
                                ),
                              )
                            : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  // List
                  Expanded(
                    child: _filteredCompanies.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            controller: scrollController, // Vital for DraggableScrollableSheet
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: _filteredCompanies.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final company = _filteredCompanies[index];
                              final isSelected = company.id == widget.selectedCompanyId;
                              
                              return _CompanyItem(
                                company: company,
                                isSelected: isSelected,
                                isDark: widget.isDark,
                                onTap: () {
                                  widget.onCompanySelected(company.id);
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: widget.isDark ? Colors.white24 : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No encontramos esa empresa',
            style: TextStyle(
              color: widget.isDark ? Colors.white54 : Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyItem extends StatelessWidget {
  const _CompanyItem({
    required this.company,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final CompanyVehicleOption company;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected 
              ? AppColors.primary
              : (isDark ? Colors.transparent : Colors.grey.withValues(alpha: 0.15)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected || !isDark
            ? [
                BoxShadow(
                  color: isSelected 
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          highlightColor: AppColors.primary.withValues(alpha: 0.1),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo
                Hero(
                  tag: 'company_logo_${company.id}',
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                    child: company.logoUrl != null && company.logoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              company.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.business_rounded,
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.business_rounded,
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: company.hasConductores 
                              ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.1))
                              : (isDark ? Colors.grey.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car_filled_rounded, 
                              size: 14, 
                              color: company.hasConductores ? AppColors.success : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              company.hasConductores 
                                  ? '${company.conductores} conductores'
                                  : 'Sin conductores',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: company.hasConductores 
                                    ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Price & Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${company.tarifaTotal.round()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check, 
                          color: Colors.white, 
                          size: 16,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white24 : Colors.black26,
                        size: 24,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../../theme/app_colors.dart';
import '../../../data/services/company_vehicle_service.dart';
import '../../../domain/models/company_vehicle_models.dart';
import 'company_details_sheet.dart';
import 'trip_price_formatter.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';


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
  final ValueChanged<int?> onCompanySelected;
  final bool isDark;

  @override
  State<CompanyPickerSheet> createState() => _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends State<CompanyPickerSheet> {
  late List<CompanyVehicleOption> _filteredCompanies;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Map<int, int> _companyTotalDrivers = {};

  @override
  void initState() {
    super.initState();
    _filteredCompanies = _sortCompaniesByRating(widget.companies);
    _searchController.addListener(_onSearchChanged);
    _prefetchCompanyDriverTotals();
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
      final filtered = widget.companies.where((company) {
        return company.nombre.toLowerCase().contains(query);
      }).toList();
      _filteredCompanies = _sortCompaniesByRating(filtered);
    });
  }

  List<CompanyVehicleOption> _sortCompaniesByRating(
    List<CompanyVehicleOption> companies,
  ) {
    final sorted = List<CompanyVehicleOption>.from(companies);
    sorted.sort((a, b) {
      final ratingCompare = b.calificacion.compareTo(a.calificacion);
      if (ratingCompare != 0) return ratingCompare;
      final driversCompare =
          _displayDriversFor(b).compareTo(_displayDriversFor(a));
      if (driversCompare != 0) return driversCompare;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return sorted;
  }

  Future<void> _prefetchCompanyDriverTotals() async {
    final uniqueCompanyIds = widget.companies.map((c) => c.id).toSet().toList();

    await Future.wait(
      uniqueCompanyIds.map((companyId) async {
        try {
          final details = await CompanyVehicleService.getCompanyDetails(companyId);
          if (!mounted || details == null) return;

          setState(() {
            _companyTotalDrivers[companyId] = details.totalConductores;
            _filteredCompanies = _sortCompaniesByRating(_filteredCompanies);
          });
        } catch (_) {
          // Silencioso: fallback al valor ya entregado por get_companies_by_municipality
        }
      }),
    );
  }

  int _displayDriversFor(CompanyVehicleOption company) {
    final totalDrivers = _companyTotalDrivers[company.id];
    if (totalDrivers != null && totalDrivers > 0) {
      return totalDrivers;
    }
    return company.conductores;
  }

  bool _hasDrivers(CompanyVehicleOption company) {
    return _displayDriversFor(company) > 0 || company.distanciaConductorKm != null;
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
                        Expanded(
                          child: Text(
                            'Seleccionar Empresa',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            itemCount: _filteredCompanies.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isRandomSelected = widget.selectedCompanyId == null;
                                return _RandomCompanyItem(
                                  isSelected: isRandomSelected,
                                  isDark: widget.isDark,
                                  onTap: () {
                                    widget.onCompanySelected(null);
                                    Navigator.pop(context);
                                  },
                                  onInfoTap: _showRandomInfo,
                                );
                              }

                              final company = _filteredCompanies[index - 1];
                              final isSelected = company.id == widget.selectedCompanyId;
                              final displayedDrivers = _displayDriversFor(company);
                              final hasDrivers = _hasDrivers(company);
                              
                              return _CompanyItem(
                                company: company,
                                isSelected: isSelected,
                                isDark: widget.isDark,
                                displayedDrivers: displayedDrivers,
                                hasDrivers: hasDrivers,
                                onTap: () {
                                  widget.onCompanySelected(company.id);
                                  Navigator.pop(context);
                                },
                                onLogoTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) => CompanyDetailsSheet(
                                      empresaId: company.id,
                                      isDark: widget.isDark,
                                    ),
                                  );
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

  void _showRandomInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shuffle_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '¿Cómo funciona Al azar?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Empieza por la empresa con el conductor más cercano para tu vehículo. Si no acepta nadie tras un tiempo, la búsqueda rota automáticamente entre otras empresas cercanas. Así hay libre competencia y menor tiempo de espera.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RandomCompanyItem extends StatelessWidget {
  const _RandomCompanyItem({
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onInfoTap,
  });

  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

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
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.shuffle_rounded, color: AppColors.primary, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Al azar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Empieza por el más cercano y rota entre empresas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onInfoTap,
                  icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyItem extends StatelessWidget {
  const _CompanyItem({
    required this.company,
    required this.isSelected,
    required this.isDark,
    required this.displayedDrivers,
    required this.hasDrivers,
    required this.onTap,
    required this.onLogoTap,
  });

  final CompanyVehicleOption company;
  final bool isSelected;
  final bool isDark;
  final int displayedDrivers;
  final bool hasDrivers;
  final VoidCallback onTap;
  final VoidCallback onLogoTap;

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
                // Logo (Tappable for details)
                GestureDetector(
                  onTap: onLogoTap,
                  child: Hero(
                    tag: 'company_logo_${company.id}',
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        // Background handled by CompanyLogo but we keep this for the shadow container
                        color: Colors.transparent, 
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
                      child: CompanyLogo(
                        logoKey: company.logoUrl,
                        nombreEmpresa: company.nombre,
                        size: 56,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
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
                          ),
                          if (company.calificacion > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300), // Amber 600
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    company.calificacion.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: hasDrivers
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
                              color: hasDrivers ? AppColors.success : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasDrivers
                                  ? '$displayedDrivers conductores'
                                  : 'Sin conductores',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: hasDrivers
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
                      formatCurrency(company.tarifaTotal),
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

import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../domain/models/trip_models.dart';
import 'trip_price_formatter.dart';
import 'trip_price_formatter.dart';
import 'company_selector_widget.dart'; // Mantener por compatibilidad o eliminar si ya no se usa
import 'company_picker_sheet.dart';
import '../../../domain/models/company_vehicle_models.dart';
import '../../../../../global/services/auth/user_service.dart';

class TripVehicleBottomSheet extends StatelessWidget {
  const TripVehicleBottomSheet({
    super.key,
    required this.controller,
    required this.slideAnimation,
    required this.isDark,
    required this.vehicles,
    required this.vehicleQuotes,
    required this.selectedVehicleType,
    required this.selectedQuote,
    required this.selectedVehicleName,
    required this.onVehicleTap,
    required this.onConfirm,
    this.companiesPerVehicle = const {},
    this.selectedCompanyIds = const {},
    this.onCompanyChanged,
    this.onOpenCompanyPicker,
    this.noVehiclesAvailable = false,
    this.noVehiclesMessage,
  });

  final DraggableScrollableController controller;
  final Animation<Offset> slideAnimation;
  final bool isDark;
  final List<VehicleInfo> vehicles;
  final Map<String, TripQuote> vehicleQuotes;
  final String selectedVehicleType;
  final TripQuote? selectedQuote;
  final String selectedVehicleName;
  final void Function(VehicleInfo vehicle, TripQuote? quote, bool isSelected)
  onVehicleTap;
  final VoidCallback onConfirm;

  // New props for company selection
  final Map<String, List<CompanyVehicleOption>> companiesPerVehicle;
  final Map<String, int> selectedCompanyIds;
  final Function(String, int)? onCompanyChanged;
  final Function(String, List<CompanyVehicleOption>)? onOpenCompanyPicker;

  // Props for empty state
  final bool noVehiclesAvailable;
  final String? noVehiclesMessage;

  @override
  Widget build(BuildContext context) {
    // Check for potential rebuild loops
    // debugPrint('🔍 TripVehicleBottomSheet: build called with ${vehicles.length} vehicles');
    
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.42,
      minChildSize: 0.2,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.2, 0.42, 0.65],
      builder: (context, scrollController) {
        return SlideTransition(
          position: slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                _DragHandle(controller: controller),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      noVehiclesAvailable
                          ? 'Sin vehículos disponibles'
                          : 'Elige tu viaje',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: noVehiclesAvailable
                      ? _buildNoVehiclesState()
                      : ListView.builder(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: vehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = vehicles[index];
                            final quote = vehicleQuotes[vehicle.type];
                            final isSelected =
                                vehicle.type == selectedVehicleType;
                            final typeCompanies =
                                companiesPerVehicle[vehicle.type] ?? [];
                            final selectedCompanyId =
                                selectedCompanyIds[vehicle.type];

                            return _VehicleListItem(
                              vehicle: vehicle,
                              quote: quote,
                              isSelected: isSelected,
                              isDark: isDark,
                              index: index,
                              onTap: () =>
                                  onVehicleTap(vehicle, quote, isSelected),
                              companies: typeCompanies,
                              selectedCompanyId: selectedCompanyId,
                              onOpenPicker: () => onOpenCompanyPicker?.call(vehicle.type, typeCompanies),
                            );
                          },
                        ),
                ),
                if (!noVehiclesAvailable)
                  _ConfirmBar(
                    isDark: isDark,
                    quote: selectedQuote,
                    vehicleName: selectedVehicleName,
                    onConfirm: onConfirm,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoVehiclesState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.car_crash_outlined,
              size: 40,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noVehiclesMessage ?? 'Sin conductores cerca',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay conductores disponibles en esta zona en este momento',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  'Intenta cambiar el punto de origen',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.controller});
  final DraggableScrollableController controller;

  static const double _minSnap = 0.2;
  static const double _closeThreshold = 0.26;
  static const double _openThreshold = 0.53;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!controller.isAttached) return;
        try {
          // If mostly open -> collapse; otherwise expand fully
          final target = controller.size > _openThreshold ? _minSnap : 0.65;
          controller.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } catch (e) {
          // Ignore if controller not ready
        }
      },
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta == null || !controller.isAttached) return;
        try {
          final delta =
              -details.primaryDelta! / 600; // scale drag to sheet size
          final newSize = (controller.size + delta).clamp(_minSnap, 0.65);
          controller.jumpTo(newSize);
        } catch (e) {
          // Ignore if controller not ready
        }
      },
      onVerticalDragEnd: (details) {
        if (!controller.isAttached) return;
        try {
          // If dragged down past threshold, hide; otherwise snap to closest state
          double current = controller.size;
          double target;
          if (current < _closeThreshold) {
            target = _minSnap;
          } else if (current > _openThreshold) {
            target = 0.65;
          } else {
            target = 0.42;
          }
          controller.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } catch (e) {
          // Ignore if controller not ready
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
      ),
    );
  }
}

class _VehicleListItem extends StatelessWidget {
  const _VehicleListItem({
    required this.vehicle,
    required this.quote,
    required this.isSelected,
    required this.isDark,
    required this.index,
    required this.onTap,
    this.companies = const [],
    this.selectedCompanyId,
    this.onOpenPicker,
  });

  final VehicleInfo vehicle;
  final TripQuote? quote;
  final bool isSelected;
  final bool isDark;
  final int index;
  final VoidCallback onTap;
  final List<CompanyVehicleOption> companies;
  final int? selectedCompanyId;
  final VoidCallback? onOpenPicker;

  @override
  Widget build(BuildContext context) {
    // Find selected company
    final selectedCompany = (companies.isNotEmpty && selectedCompanyId != null)
        ? companies.firstWhere(
            (c) => c.id == selectedCompanyId,
            orElse: () => companies.first,
          )
        : (companies.isNotEmpty ? companies.first : null);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSelected
                    ? (isDark
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.08))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                   Row(
                    children: [
                      SizedBox(
                        width: 60,
                        height: 40,
                        child: Image.asset(
                          vehicle.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              vehicle.icon,
                              size: 32,
                              color: isDark ? Colors.white60 : Colors.black45,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  vehicle.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppColors.primary.withValues(alpha: 0.7),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              quote != null
                                  ? '${quote!.formattedDuration} · ${vehicle.description}'
                                  : vehicle.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (quote != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCurrency(quote!.totalPrice),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            if (quote!.surchargePercentage > 0)
                              Text(
                                _surchargeLabel(quote!),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                   
                  // Operado por / Empresa Badge
                  if (isSelected && selectedCompany != null) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: companies.length > 1 ? onOpenPicker : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min, // Keep it compact
                          children: [
                            Text(
                              'Operado por:',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Logo small
                            if (selectedCompany.logoUrl != null && selectedCompany.logoUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  UserService.getR2ImageUrl(selectedCompany.logoUrl),
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_,__,___) => const Icon(Icons.business, size: 16),
                                ),
                              )
                            else 
                              Icon(Icons.business, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                              
                            const SizedBox(width: 6),
                            Text(
                              selectedCompany.nombre,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            
                            if (selectedCompany.calificacion > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300), // Amber 600
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB300).withValues(alpha: 0.25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      selectedCompany.calificacion.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            if (companies.length > 1) ...[
                              const Spacer(),
                              Text(
                                'Cambiar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_right, size: 16, color: AppColors.primary),
                            ] else 
                              const Spacer(), // Just to fill row
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Removed inline CompanySelectorWidget here
        ],
      ),
    );
  }

  String _surchargeLabel(TripQuote quote) {
    final suffix = quote.periodType == 'nocturno' ? 'noct.' : 'pico';
    return '+${quote.surchargePercentage.toInt()}% $suffix';
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.isDark,
    required this.quote,
    required this.vehicleName,
    required this.onConfirm,
  });

  final bool isDark;
  final TripQuote? quote;
  final String vehicleName;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vehicleName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (quote != null)
                  Text(
                    quote!.formattedTotal,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Confirmar $vehicleName',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

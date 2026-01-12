import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../domain/models/company_vehicle_models.dart';

class CompanyPickerSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.business_rounded, 
                  color: isDark ? Colors.white : Colors.black87,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Elige la empresa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: companies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final company = companies[index];
                final isSelected = company.id == selectedCompanyId;
                
                return _CompanyItem(
                  company: company,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () {
                    onCompanySelected(company.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected 
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            // Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: company.logoUrl != null && company.logoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        company.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.business,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.business,
                      color: isDark ? Colors.white54 : Colors.black45,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person, 
                        size: 14, 
                        color: company.hasConductores ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        company.hasConductores 
                            ? '${company.conductores} conductores cerca'
                            : 'Sin conductores cerca',
                        style: TextStyle(
                          fontSize: 13,
                          color: company.hasConductores 
                              ? (isDark ? Colors.green.shade400 : Colors.green.shade700)
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Price & Selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${company.tarifaTotal.toInt()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 4),
                  Icon(
                    Icons.check_circle, 
                    color: AppColors.primary, 
                    size: 20,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

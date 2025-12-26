import 'dart:io';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/features/conductor/presentation/widgets/components/image_upload_card.dart';

class VehicleStepWidget extends StatelessWidget {
  final bool isDark;
  final String selectedVehicleType;
  final ValueChanged<String> onTypeSelected;
  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController colorController;
  final TextEditingController plateController;
  final File? vehiclePhoto;
  final VoidCallback onPickPhoto;
  final Map<String, dynamic>? selectedCompany;
  final TextEditingController companyController;
  final VoidCallback onShowCompanyPicker;

  const VehicleStepWidget({
    super.key,
    required this.isDark,
    required this.selectedVehicleType,
    required this.onTypeSelected,
    required this.brandController,
    required this.modelController,
    required this.yearController,
    required this.colorController,
    required this.plateController,
    required this.vehiclePhoto,
    required this.onPickPhoto,
    required this.selectedCompany,
    required this.companyController,
    required this.onShowCompanyPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 24),
        _buildVehicleTypeSelector(context),
        const SizedBox(height: 32),
        _buildVehicleDetailsForm(context),
        const SizedBox(height: 32),
        _buildPhotoUploadSection(context),
        const SizedBox(height: 24),
        _buildCompanySection(context),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu Vehículo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona el tipo de vehículo y completa los detalles para comenzar.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white60 : Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeSelector(BuildContext context) {
    final List<Map<String, dynamic>> types = [
      {'id': 'moto', 'icon': Icons.two_wheeler_rounded, 'label': 'Moto'},
      {'id': 'carro', 'icon': Icons.directions_car_rounded, 'label': 'Carro'},
      {'id': 'taxi', 'icon': Icons.local_taxi_rounded, 'label': 'Taxi'},
      {'id': 'motocarro', 'icon': Icons.electric_rickshaw_rounded, 'label': 'Motocarro'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        final isSelected = selectedVehicleType == type['id'];
        return _buildTypeCard(context, type['id'] as String, type['icon'] as IconData, type['label'] as String, isSelected);
      },
    );
  }

  Widget _buildTypeCard(BuildContext context, String id, IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => onTypeSelected(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: isSelected 
                 ? AppColors.primary 
                 : (isDark ? Colors.white12 : Colors.grey.shade200),
             width: isSelected ? 2 : 1.5
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: -2
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.grey.shade50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (isSelected) 
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: Colors.white, size: 16),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDetailsForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.05),
             blurRadius: 20,
             offset: const Offset(0, 10),
           )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.commute_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Detalles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: brandController,
            label: 'Marca',
            icon: Icons.branding_watermark_rounded,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: modelController,
            label: 'Modelo (Ref)',
            icon: Icons.model_training_rounded,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: yearController,
            label: 'Año',
            icon: Icons.calendar_today_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: colorController,
            label: 'Color',
            icon: Icons.color_lens_rounded,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: plateController,
            label: 'Placa',
            icon: Icons.tag_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadSection(BuildContext context) {
    return ImageUploadCard(
      label: 'Foto del Vehículo',
      file: vehiclePhoto,
      onTap: onPickPhoto,
      isDark: isDark,
    );
  }

  Widget _buildCompanySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Empresa de Transporte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        GestureDetector(
          onTap: onShowCompanyPicker,
          child: Container(
            padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
              boxShadow: [
                 BoxShadow(
                   color: Colors.black.withOpacity(0.03),
                   blurRadius: 10,
                   offset: const Offset(0, 4),
                 )
              ]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                         companyController.text.isEmpty ? 'Seleccionar Empresa' : companyController.text,
                         style: TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: isDark ? Colors.white : Colors.black87,
                         ),
                      ),
                      if (companyController.text.isEmpty)
                      Text(
                        'Opcional',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

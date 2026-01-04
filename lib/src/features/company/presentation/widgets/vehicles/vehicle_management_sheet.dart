import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';

class VehicleManagementSheet extends StatefulWidget {
  final dynamic empresaId;
  final List<String> currentVehicleTypes;

  const VehicleManagementSheet({
    super.key,
    required this.empresaId,
    required this.currentVehicleTypes,
  });

  @override
  State<VehicleManagementSheet> createState() => _VehicleManagementSheetState();
}

class _VehicleManagementSheetState extends State<VehicleManagementSheet> {
  List<String> _enabledTypes = [];
  bool _isSaving = false;
  bool _isLoading = true;

  static const List<Map<String, dynamic>> _allVehicleTypes = [
    {'key': 'moto', 'name': 'Moto', 'icon': Icons.two_wheeler_rounded, 'description': 'Motocicletas'},
    {'key': 'auto', 'name': 'Auto', 'icon': Icons.directions_car_rounded, 'description': 'Automóviles'},
    {'key': 'motocarro', 'name': 'Motocarro', 'icon': Icons.electric_rickshaw_rounded, 'description': 'Motocarros de carga'},
  ];

  @override
  void initState() {
    super.initState();
    _enabledTypes = List<String>.from(widget.currentVehicleTypes);
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/company/vehicles.php?empresa_id=${widget.empresaId}');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _enabledTypes = List<String>.from(data['data']['vehiculos'] ?? []);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleVehicleType(String tipo, bool enable) async {
    setState(() => _isSaving = true);
    
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/company/vehicles.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'empresa_id': widget.empresaId,
          'tipo_vehiculo': tipo,
          'activo': enable ? 1 : 0,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            if (enable) {
              if (!_enabledTypes.contains(tipo)) _enabledTypes.add(tipo);
            } else {
              _enabledTypes.remove(tipo);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(enable ? 'Vehículo habilitado' : 'Vehículo deshabilitado'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          _showError(data['message'] ?? 'Error desconocido');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tipos de Vehículo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Habilita o deshabilita tipos',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, height: 1),
          
          // Vehicle Types List
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _allVehicleTypes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vehicle = _allVehicleTypes[index];
                final isEnabled = _enabledTypes.contains(vehicle['key']);
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? (isEnabled ? AppColors.primary.withValues(alpha: 0.1) : AppColors.darkCard)
                        : (isEnabled ? AppColors.blue50 : Colors.grey.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isEnabled 
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isEnabled ? AppColors.primary : Colors.grey).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          vehicle['icon'] as IconData,
                          color: isEnabled ? AppColors.primary : Colors.grey,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle['name'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              vehicle['description'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSaving)
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          value: isEnabled,
                          onChanged: (value) => _toggleVehicleType(vehicle['key'] as String, value),
                          activeColor: AppColors.primary,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Info Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Al habilitar un tipo, se creará una configuración de tarifas para ese vehículo.',
                      style: TextStyle(fontSize: 12, color: AppColors.blue800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

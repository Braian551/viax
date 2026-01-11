import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';

class VehicleManagementSheet extends StatefulWidget {
  final dynamic empresaId;
  final List<String> currentVehicleTypes;
  final int? usuarioId;

  const VehicleManagementSheet({
    super.key,
    required this.empresaId,
    required this.currentVehicleTypes,
    this.usuarioId,
  });

  @override
  State<VehicleManagementSheet> createState() => _VehicleManagementSheetState();
}

class _VehicleManagementSheetState extends State<VehicleManagementSheet> {
  Map<String, VehicleTypeInfo> _vehicleTypes = {};
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
    _initializeVehicleTypes();
    _loadVehicles();
  }

  void _initializeVehicleTypes() {
    for (var type in _allVehicleTypes) {
      final key = type['key'] as String;
      _vehicleTypes[key] = VehicleTypeInfo(
        codigo: key,
        nombre: type['name'] as String,
        descripcion: type['description'] as String,
        activo: widget.currentVehicleTypes.contains(key),
        conductoresActivos: 0,
      );
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/company/vehicles.php?empresa_id=${widget.empresaId}');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final vehiculosActivos = List<String>.from(data['data']['vehiculos'] ?? []);
          final tiposEmpresa = data['data']['tipos_empresa'] as List?;
          
          setState(() {
            // Actualizar estado de cada tipo
            for (var key in _vehicleTypes.keys) {
              _vehicleTypes[key] = _vehicleTypes[key]!.copyWith(
                activo: vehiculosActivos.contains(key),
              );
            }
            
            // Si hay info detallada de la tabla normalizada, usarla
            if (tiposEmpresa != null) {
              for (var tipo in tiposEmpresa) {
                final codigo = tipo['codigo']?.toString() ?? '';
                if (_vehicleTypes.containsKey(codigo)) {
                  _vehicleTypes[codigo] = _vehicleTypes[codigo]!.copyWith(
                    activo: tipo['activo'] == true || tipo['activo'] == 1,
                    conductoresActivos: tipo['conductores_activos'] ?? 0,
                  );
                }
              }
            }
            
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
    final info = _vehicleTypes[tipo];
    if (info == null) return;
    
    // Si se va a desactivar y hay conductores, mostrar confirmación
    if (!enable && info.conductoresActivos > 0) {
      final confirmed = await _showDeactivateConfirmation(tipo, info);
      if (confirmed != true) return;
    }
    
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
          'usuario_id': widget.usuarioId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _vehicleTypes[tipo] = _vehicleTypes[tipo]!.copyWith(activo: enable);
          });
          
          final conductoresAfectados = data['data']?['conductores_afectados'] ?? 0;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enable 
                    ? 'Vehículo habilitado' 
                    : conductoresAfectados > 0
                        ? 'Vehículo deshabilitado. Se notificó a $conductoresAfectados conductor(es).'
                        : 'Vehículo deshabilitado',
              ),
              backgroundColor: enable ? AppColors.success : AppColors.warning,
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

  Future<bool?> _showDeactivateConfirmation(String tipo, VehicleTypeInfo info) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Confirmar desactivación', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de desactivar "${info.nombre}"?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${info.conductoresActivos} conductor(es) serán notificados',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Los conductores con este tipo de vehículo recibirán un email informándoles del cambio.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
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
                final key = vehicle['key'] as String;
                final info = _vehicleTypes[key];
                final isEnabled = info?.activo ?? false;
                final conductores = info?.conductoresActivos ?? 0;
                
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
                            if (isEnabled && conductores > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$conductores conductor(es)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                          onChanged: (value) => _toggleVehicleType(key, value),
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

/// Modelo para información de tipo de vehículo
class VehicleTypeInfo {
  final String codigo;
  final String nombre;
  final String descripcion;
  final bool activo;
  final int conductoresActivos;
  final DateTime? fechaActivacion;
  final DateTime? fechaDesactivacion;
  final String? motivoDesactivacion;

  VehicleTypeInfo({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    this.conductoresActivos = 0,
    this.fechaActivacion,
    this.fechaDesactivacion,
    this.motivoDesactivacion,
  });

  VehicleTypeInfo copyWith({
    String? codigo,
    String? nombre,
    String? descripcion,
    bool? activo,
    int? conductoresActivos,
    DateTime? fechaActivacion,
    DateTime? fechaDesactivacion,
    String? motivoDesactivacion,
  }) {
    return VehicleTypeInfo(
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
      conductoresActivos: conductoresActivos ?? this.conductoresActivos,
      fechaActivacion: fechaActivacion ?? this.fechaActivacion,
      fechaDesactivacion: fechaDesactivacion ?? this.fechaDesactivacion,
      motivoDesactivacion: motivoDesactivacion ?? this.motivoDesactivacion,
    );
  }
}

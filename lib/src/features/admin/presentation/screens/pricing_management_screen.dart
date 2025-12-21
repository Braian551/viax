import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';

class PricingManagementScreen extends StatefulWidget {
  final Map<String, dynamic> adminUser;

  const PricingManagementScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<PricingManagementScreen> createState() => _PricingManagementScreenState();
}

class _PricingManagementScreenState extends State<PricingManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pricingConfigs = [];
  String? _errorMessage;
  
  final Map<String, String> _vehicleTypeNames = {
    'moto': 'Moto',
  };

  final Map<String, IconData> _vehicleTypeIcons = {
    'moto': Icons.two_wheeler_rounded,
  };

  final Map<String, Color> _vehicleTypeColors = {
    'moto': AppColors.primary,
  };

  @override
  void initState() {
    super.initState();
    _loadPricingConfigs();
  }

  Future<void> _loadPricingConfigs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/admin/get_pricing_configs.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final allConfigs = List<Map<String, dynamic>>.from(data['data'] ?? []);
          
          // Filtrar para obtener solo la última configuración activa por tipo de vehículo
          final Map<String, Map<String, dynamic>> uniqueConfigs = {};
          
          for (var config in allConfigs) {
            final tipo = config['tipo_vehiculo'] as String;
            final isActive = config['activo'] == 1 || config['activo'] == '1';
            
            // Solo tomar configuraciones activas
            if (isActive) {
              // Si no existe o si el ID es mayor (más reciente), actualizar
              if (!uniqueConfigs.containsKey(tipo) || 
                  (int.tryParse(config['id'].toString()) ?? 0) > 
                  (int.tryParse(uniqueConfigs[tipo]!['id'].toString()) ?? 0)) {
                uniqueConfigs[tipo] = config;
              }
            }
          }
          
          setState(() {
            _pricingConfigs = uniqueConfigs.values.toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Error al cargar configuraciones';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Icon(Icons.attach_money_rounded, color: AppColors.primary, size: 28),
          SizedBox(width: 12),
          Text(
            'Tarifas y Precios',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: _loadPricingConfigs,
          tooltip: 'Recargar',
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Cargando configuraciones...',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFf5576c).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFf5576c), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'Error desconocido',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadPricingConfigs,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_pricingConfigs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 80),
            const SizedBox(height: 16),
            Text(
              'No hay configuraciones de precios',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPricingConfigs,
      color: AppColors.primary,
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _pricingConfigs.length,
        itemBuilder: (context, index) {
          final config = _pricingConfigs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPricingCard(config),
          );
        },
      ),
    );
  }

  Widget _buildPricingCard(Map<String, dynamic> config) {
    final tipoVehiculo = config['tipo_vehiculo'] ?? '';
    final activo = config['activo'] == 1 || config['activo'] == '1';
    final color = _vehicleTypeColors[tipoVehiculo] ?? Colors.grey;
    final icon = _vehicleTypeIcons[tipoVehiculo] ?? Icons.help_rounded;
    final nombre = _vehicleTypeNames[tipoVehiculo] ?? tipoVehiculo;

    return GestureDetector(
      onTap: () => _showEditDialog(config),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: activo ? color.withValues(alpha: 0.6) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                        child: Icon(icon, color: color, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: activo 
                                  ? const Color(0xFF34C759).withValues(alpha: 0.2)
                                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: activo 
                                      ? const Color(0xFF34C759).withValues(alpha: 0.5)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                activo ? 'ACTIVO' : 'INACTIVO',
                                style: TextStyle(
                                  color: activo ? const Color(0xFF34C759) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.edit_rounded, color: color, size: 22),
                      ),
                    ],
                  ),
                ),
                // Datos
                Container(
                  padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                    ),
                  child: Column(
                    children: [
                      // Tarifas Base
                      _buildSectionTitle('Tarifas Base', Icons.attach_money_rounded),
                      _buildInfoRow('Tarifa Base', '\$${_formatNumber(config['tarifa_base'])}', Theme.of(context).colorScheme.onSurface),
                      _buildInfoRow('Tarifa Mínima', '\$${_formatNumber(config['tarifa_minima'])}', Theme.of(context).colorScheme.onSurface),
                      _buildInfoRow('Tarifa Máxima', config['tarifa_maxima'] != null ? '\$${_formatNumber(config['tarifa_maxima'])}' : 'Sin límite', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 28, thickness: 1),
                      
                      // Costos por Distancia y Tiempo
                      _buildSectionTitle('Costos por Distancia y Tiempo', Icons.straighten_rounded),
                      _buildInfoRow('Costo por Km', '\$${_formatNumber(config['costo_por_km'])}', color),
                      _buildInfoRow('Costo por Minuto', '\$${_formatNumber(config['costo_por_minuto'])}', color),
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 28, thickness: 1),
                      
                      // Recargos
                      _buildSectionTitle('Recargos', Icons.trending_up_rounded),
                      _buildInfoRow('Hora Pico', '${config['recargo_hora_pico']}%', const Color(0xFFFF9500)),
                      _buildInfoRow('Nocturno', '${config['recargo_nocturno']}%', const Color(0xFF5E5CE6)),
                      _buildInfoRow('Festivo', '${config['recargo_festivo']}%', const Color(0xFF32D74B)),
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 28, thickness: 1),
                      
                      // Descuentos
                      _buildSectionTitle('Descuentos', Icons.local_offer_rounded),
                      _buildInfoRow('Descuento Dist. Larga', '${config['descuento_distancia_larga']}%', const Color(0xFF30D158)),
                      _buildInfoRow('Umbral para Descuento', '${_formatNumber(config['umbral_km_descuento'])} km', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 28, thickness: 1),
                      
                      // Comisiones
                      _buildSectionTitle('Comisiones', Icons.credit_card_rounded),
                      _buildInfoRow('Plataforma', '${config['comision_plataforma']}%', const Color(0xFFFFD60A)),
                      _buildInfoRow('MÃ©todo de Pago', '${config['comision_metodo_pago']}%', const Color(0xFFFF9F0A)),
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 28, thickness: 1),
                      
                      // LÃ­mites de Distancia
                      _buildSectionTitle('Límites de Distancia', Icons.route_rounded),
                      _buildInfoRow('Distancia Mínima', '${_formatNumber(config['distancia_minima'])} km', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      _buildInfoRow('Distancia Máxima', '${_formatNumber(config['distancia_maxima'])} km', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 28, thickness: 1),
                      
                      // Tiempo de Espera
                      _buildSectionTitle('Tiempo de Espera', Icons.timer_rounded),
                      _buildInfoRow('Espera Gratis', '${config['tiempo_espera_gratis']} min', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      _buildInfoRow('Costo por Min Espera', '\$${_formatNumber(config['costo_tiempo_espera'])}', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = double.tryParse(value.toString()) ?? 0.0;
    return number.toStringAsFixed(0);
  }

  Future<void> _showEditDialog(Map<String, dynamic> config) async {
    final controllers = {
      // Tarifas base
      'tarifa_base': TextEditingController(text: config['tarifa_base']?.toString() ?? '0'),
      'tarifa_minima': TextEditingController(text: config['tarifa_minima']?.toString() ?? '0'),
      'tarifa_maxima': TextEditingController(text: config['tarifa_maxima']?.toString() ?? ''),
      
      // Costos por distancia y tiempo
      'costo_por_km': TextEditingController(text: config['costo_por_km']?.toString() ?? '0'),
      'costo_por_minuto': TextEditingController(text: config['costo_por_minuto']?.toString() ?? '0'),
      
      // Recargos
      'recargo_hora_pico': TextEditingController(text: config['recargo_hora_pico']?.toString() ?? '0'),
      'recargo_nocturno': TextEditingController(text: config['recargo_nocturno']?.toString() ?? '0'),
      'recargo_festivo': TextEditingController(text: config['recargo_festivo']?.toString() ?? '0'),
      
      // Descuentos
      'descuento_distancia_larga': TextEditingController(text: config['descuento_distancia_larga']?.toString() ?? '0'),
      'umbral_km_descuento': TextEditingController(text: config['umbral_km_descuento']?.toString() ?? '0'),
      
      // Horarios Pico
      'hora_pico_inicio_manana': TextEditingController(text: config['hora_pico_inicio_manana']?.toString() ?? '07:00'),
      'hora_pico_fin_manana': TextEditingController(text: config['hora_pico_fin_manana']?.toString() ?? '09:00'),
      'hora_pico_inicio_tarde': TextEditingController(text: config['hora_pico_inicio_tarde']?.toString() ?? '17:00'),
      'hora_pico_fin_tarde': TextEditingController(text: config['hora_pico_fin_tarde']?.toString() ?? '19:00'),
      
      // Horarios Nocturnos
      'hora_nocturna_inicio': TextEditingController(text: config['hora_nocturna_inicio']?.toString() ?? '22:00'),
      'hora_nocturna_fin': TextEditingController(text: config['hora_nocturna_fin']?.toString() ?? '06:00'),
      
      // Comisiones
      'comision_plataforma': TextEditingController(text: config['comision_plataforma']?.toString() ?? '0'),
      'comision_metodo_pago': TextEditingController(text: config['comision_metodo_pago']?.toString() ?? '0'),
      
      // LÃ­mites
      'distancia_minima': TextEditingController(text: config['distancia_minima']?.toString() ?? '0'),
      'distancia_maxima': TextEditingController(text: config['distancia_maxima']?.toString() ?? '0'),
      
      // Tiempo de espera
      'tiempo_espera_gratis': TextEditingController(text: config['tiempo_espera_gratis']?.toString() ?? '0'),
      'costo_tiempo_espera': TextEditingController(text: config['costo_tiempo_espera']?.toString() ?? '0'),
      
      // Notas
      'notas': TextEditingController(text: config['notas']?.toString() ?? ''),
    };

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing while saving
      builder: (context) => _EditPricingDialog(
        config: config,
        controllers: controllers,
        vehicleTypeName: _vehicleTypeNames[config['tipo_vehiculo']] ?? '',
        vehicleTypeColor: _vehicleTypeColors[config['tipo_vehiculo']] ?? Colors.grey,
      ),
    );

    // Dispose controllers after dialog is fully closed
    await Future.delayed(const Duration(milliseconds: 100));
    for (var controller in controllers.values) {
      controller.dispose();
    }

    if (result == true) {
      _loadPricingConfigs();
    }
  }
}

class _EditPricingDialog extends StatefulWidget {
  final Map<String, dynamic> config;
  final Map<String, TextEditingController> controllers;
  final String vehicleTypeName;
  final Color vehicleTypeColor;

  const _EditPricingDialog({
    required this.config,
    required this.controllers,
    required this.vehicleTypeName,
    required this.vehicleTypeColor,
  });

  @override
  State<_EditPricingDialog> createState() => _EditPricingDialogState();
}

class _EditPricingDialogState extends State<_EditPricingDialog> {
  bool _isSaving = false;

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updateData = {
        'id': widget.config['id'],
      };

      // Helper function to add field
      void addField(String key, String controllerKey, {bool isDouble = true, bool isInt = false, bool required = true}) {
        final text = widget.controllers[controllerKey]!.text.trim();
        if (text.isEmpty) {
          if (required) {
            throw FormatException('El campo $key es obligatorio');
          }
          return; // Skip optional empty fields
        }
        if (isDouble) {
          updateData[key] = double.parse(text);
        } else if (isInt) {
          updateData[key] = int.parse(text);
        } else {
          updateData[key] = text;
        }
      }

      // Tarifas Base
      addField('tarifa_base', 'tarifa_base');
      addField('tarifa_minima', 'tarifa_minima');
      addField('tarifa_maxima', 'tarifa_maxima', required: false); // Optional

      // Costos
      addField('costo_por_km', 'costo_por_km');
      addField('costo_por_minuto', 'costo_por_minuto');

      // Recargos
      addField('recargo_hora_pico', 'recargo_hora_pico');
      addField('recargo_nocturno', 'recargo_nocturno');
      addField('recargo_festivo', 'recargo_festivo');

      // Descuentos
      addField('descuento_distancia_larga', 'descuento_distancia_larga');
      addField('umbral_km_descuento', 'umbral_km_descuento');

      // Horarios Pico
      addField('hora_pico_inicio_manana', 'hora_pico_inicio_manana', isDouble: false);
      addField('hora_pico_fin_manana', 'hora_pico_fin_manana', isDouble: false);
      addField('hora_pico_inicio_tarde', 'hora_pico_inicio_tarde', isDouble: false);
      addField('hora_pico_fin_tarde', 'hora_pico_fin_tarde', isDouble: false);

      // Horarios Nocturnos
      addField('hora_nocturna_inicio', 'hora_nocturna_inicio', isDouble: false);
      addField('hora_nocturna_fin', 'hora_nocturna_fin', isDouble: false);

      // Comisiones
      addField('comision_plataforma', 'comision_plataforma');
      addField('comision_metodo_pago', 'comision_metodo_pago');

      // LÃ­mites
      addField('distancia_minima', 'distancia_minima');
      addField('distancia_maxima', 'distancia_maxima');

      // Tiempo de Espera
      addField('tiempo_espera_gratis', 'tiempo_espera_gratis', isDouble: false, isInt: true);
      addField('costo_tiempo_espera', 'costo_tiempo_espera');

      // Notas (opcional)
      final notas = widget.controllers['notas']!.text.trim();
      if (notas.isNotEmpty) {
        updateData['notas'] = notas;
      }

      final url = Uri.parse('${AppConfig.baseUrl}/admin/update_pricing_config.php');
      final client = http.Client();
      try {
        final response = await client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updateData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Configuración actualizada exitosamente'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            Navigator.pop(context, true);
          } else {
            _showError(data['message'] ?? 'Error al actualizar');
          }
        } else {
          _showError('Error del servidor: ${response.statusCode}');
        }
      } on TimeoutException {
        _showError('Tiempo de espera agotado. Verifica la conexiÃ³n al servidor.');
      } catch (e) {
        _showError('Error: $e');
      } finally {
        client.close();
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFf5576c),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isSaving, // Prevent back button during save
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: widget.vehicleTypeColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.vehicleTypeColor.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: widget.vehicleTypeColor.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    border: Border(
                      bottom: BorderSide(
                        color: widget.vehicleTypeColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.vehicleTypeColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.vehicleTypeColor.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Icon(Icons.edit_rounded, color: widget.vehicleTypeColor, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editar Tarifas',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.vehicleTypeName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormSectionTitle('Tarifas Base', Icons.attach_money_rounded),
                        _buildTextField('Tarifa Base (\$)', widget.controllers['tarifa_base']!),
                        _buildTextField('Tarifa Mínima (\$)', widget.controllers['tarifa_minima']!),
                        _buildTextField('Tarifa Máxima (\$) - Opcional', widget.controllers['tarifa_maxima']!, optional: true),
                        
                        const SizedBox(height: 24),
                        _buildFormSectionTitle('Costos por Distancia y Tiempo', Icons.straighten_rounded),
                        _buildTextField('Costo por Km (\$)', widget.controllers['costo_por_km']!),
                        _buildTextField('Costo por Minuto (\$)', widget.controllers['costo_por_minuto']!),
                        
                        const SizedBox(height: 24),
                        _buildFormSectionTitle('Recargos (%)', Icons.trending_up_rounded),
                        _buildTextField('Recargo Hora Pico (%)', widget.controllers['recargo_hora_pico']!),
                        _buildTextField('Recargo Nocturno (%)', widget.controllers['recargo_nocturno']!),
                        _buildTextField('Recargo Festivo (%)', widget.controllers['recargo_festivo']!),
                        
                        const SizedBox(height: 24),
                        _buildFormSectionTitle('Descuentos', Icons.local_offer_rounded),
                        _buildTextField('Descuento Distancia Larga (%)', widget.controllers['descuento_distancia_larga']!),
                        _buildTextField('Umbral para Descuento (km)', widget.controllers['umbral_km_descuento']!),
                        
                        const SizedBox(height: 24),
                        _buildFormSectionTitle('Comisiones (%)', Icons.credit_card_rounded),
                        _buildTextField('Comisión Plataforma (%)', widget.controllers['comision_plataforma']!),
                        _buildTextField('Comisión Método Pago (%)', widget.controllers['comision_metodo_pago']!),
                        
                        const SizedBox(height: 24),
                        _buildFormSectionTitle('LÃ­mites de Distancia', Icons.route_rounded),
                        _buildTextField('Distancia MÃ­nima (km)', widget.controllers['distancia_minima']!),
                        _buildTextField('Distancia MÃ¡xima (km)', widget.controllers['distancia_maxima']!),
                        
                        const SizedBox(height: 24),
                        _buildFormSectionTitle('Tiempo de Espera', Icons.timer_rounded),
                        _buildTextField('Tiempo Espera Gratis (min)', widget.controllers['tiempo_espera_gratis']!),
                        _buildTextField('Costo por Minuto Espera (\$)', widget.controllers['costo_tiempo_espera']!),
                      ],
                    ),
                  ),
                ),
                // Buttons
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: widget.vehicleTypeColor,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : const Text(
                                  'Guardar',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildFormSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: widget.vehicleTypeColor.withValues(alpha: 0.9), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: widget.vehicleTypeColor.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(optional ? r'^(\d+\.?\d{0,2})?' : r'^\d+\.?\d{0,2}')),
        ],
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 15,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.vehicleTypeColor.withValues(alpha: 0.6), width: 2),
          ),
        ),
      ),
    );
  }
}





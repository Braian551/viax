import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';

class CompanyPricingTab extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyPricingTab({super.key, required this.user});

  @override
  State<CompanyPricingTab> createState() => _CompanyPricingTabState();
}

class _CompanyPricingTabState extends State<CompanyPricingTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pricingConfigs = [];
  String? _errorMessage;
  
  final Map<String, String> _vehicleTypeNames = {
    'moto': 'Moto',
    'auto': 'Auto',
    'motocarro': 'Motocarro',
  };

  final Map<String, IconData> _vehicleTypeIcons = {
    'moto': Icons.two_wheeler_rounded,
    'auto': Icons.directions_car_rounded,
    'motocarro': Icons.electric_rickshaw_rounded,
  };

  final Map<String, Color> _vehicleTypeColors = {
    'moto': AppColors.primary,
    'auto': Colors.blue,
    'motocarro': Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final empresaId = widget.user['empresa_id'] ?? widget.user['id']; 
      
      final url = Uri.parse('${AppConfig.baseUrl}/company/pricing.php?empresa_id=$empresaId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _pricingConfigs = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
           _errorMessage = 'Error: ${response.statusCode}';
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

  Future<void> _showEditDialog(Map<String, dynamic> config) async {
    final controllers = {
      'tarifa_base': TextEditingController(text: config['tarifa_base']?.toString() ?? '0'),
      'costo_por_km': TextEditingController(text: config['costo_por_km']?.toString() ?? '0'),
      'costo_por_minuto': TextEditingController(text: config['costo_por_minuto']?.toString() ?? '0'),
      'tarifa_minima': TextEditingController(text: config['tarifa_minima']?.toString() ?? '0'),
    };

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditPricingDialog(
        config: config,
        controllers: controllers,
        vehicleTypeName: _vehicleTypeNames[config['tipo_vehiculo']] ?? config['tipo_vehiculo'],
        vehicleTypeColor: _vehicleTypeColors[config['tipo_vehiculo']] ?? Colors.grey,
        empresaId: widget.user['empresa_id'] ?? widget.user['id'],
      ),
    );

    for (var controller in controllers.values) {
      controller.dispose();
    }

    if (result == true) {
      _loadPricing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text('Error: $_errorMessage'));
    
    if (_pricingConfigs.isEmpty) {
        return const Center(child: Text('No hay información de tarifas disponible.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pricingConfigs.length,
      itemBuilder: (context, index) {
        return _buildPricingCard(_pricingConfigs[index]);
      },
    );
  }

  Widget _buildPricingCard(Map<String, dynamic> config) {
     final tipo = config['tipo_vehiculo'];
     final color = _vehicleTypeColors[tipo] ?? Colors.grey;
     final icon = _vehicleTypeIcons[tipo] ?? Icons.local_shipping_rounded;
     final isGlobal = config['es_global'] == true;

     return Card(
       margin: const EdgeInsets.only(bottom: 16),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       elevation: 4,
       child: Padding(
         padding: const EdgeInsets.all(16),
         child: Column(
           children: [
             Row(
               children: [
                 Icon(icon, color: color, size: 32),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Text(
                     _vehicleTypeNames[tipo] ?? tipo.toUpperCase(),
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                 ),
                 if (isGlobal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Usando Estándar', style: TextStyle(fontSize: 12)),
                    ),
               ],
             ),
             const Divider(),
             _buildRow('Tarifa Base:', '\$${config['tarifa_base']}'),
             _buildRow('Km:', '\$${config['costo_por_km']}'),
             _buildRow('Minuto:', '\$${config['costo_por_minuto']}'),
             const SizedBox(height: 12),
             ElevatedButton(
               onPressed: () => _showEditDialog(config),
               style: ElevatedButton.styleFrom(
                 backgroundColor: color,
                 foregroundColor: Colors.white,
               ),
               child: const Text('Editar Tarifas'),
             ),
           ],
         ),
       ),
     );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EditPricingDialog extends StatefulWidget {
  final Map<String, dynamic> config;
  final Map<String, TextEditingController> controllers;
  final String vehicleTypeName;
  final Color vehicleTypeColor;
  final dynamic empresaId;

  const _EditPricingDialog({
    required this.config,
    required this.controllers,
    required this.vehicleTypeName,
    required this.vehicleTypeColor,
    required this.empresaId,
  });

  @override
  State<_EditPricingDialog> createState() => _EditPricingDialogState();
}

class _EditPricingDialogState extends State<_EditPricingDialog> {
  bool _isSaving = false;

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final updateItem = {
        'tipo_vehiculo': widget.config['tipo_vehiculo'],
        'activo': 1, // Always active if edited
        'tarifa_base': double.tryParse(widget.controllers['tarifa_base']!.text) ?? 0,
        'costo_por_km': double.tryParse(widget.controllers['costo_por_km']!.text) ?? 0,
        'costo_por_minuto': double.tryParse(widget.controllers['costo_por_minuto']!.text) ?? 0,
        'tarifa_minima': double.tryParse(widget.controllers['tarifa_minima']!.text) ?? 0,
        // Preservar valores originales si no se editan
        'recargo_hora_pico': widget.config['recargo_hora_pico'] ?? 0,
        'recargo_nocturno': widget.config['recargo_nocturno'] ?? 0,
        'recargo_festivo': widget.config['recargo_festivo'] ?? 0,
        'comision_plataforma': widget.config['comision_plataforma'] ?? 0,
      };

      final body = {
        'empresa_id': widget.empresaId,
        'precios': [updateItem]
      };

      final url = Uri.parse('${AppConfig.baseUrl}/company/pricing.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) Navigator.pop(context, true);
        } else {
          _showError(data['message']);
        }
      } else {
        _showError('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: Padding(
         padding: const EdgeInsets.all(20),
         child: SingleChildScrollView(
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text('Editar ${widget.vehicleTypeName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               TextField(
                 controller: widget.controllers['tarifa_base'],
                 decoration: const InputDecoration(labelText: 'Tarifa Base', border: OutlineInputBorder()),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: widget.controllers['costo_por_km'],
                 decoration: const InputDecoration(labelText: 'Costo por KM', border: OutlineInputBorder()),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: widget.controllers['costo_por_minuto'],
                 decoration: const InputDecoration(labelText: 'Costo por Minuto', border: OutlineInputBorder()),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: widget.controllers['tarifa_minima'],
                 decoration: const InputDecoration(labelText: 'Tarifa Mínima', border: OutlineInputBorder()),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 24),
               Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
                   const SizedBox(width: 8),
                   ElevatedButton(
                     onPressed: _isSaving ? null : _saveChanges,
                     child: _isSaving ? const CircularProgressIndicator() : const Text('Guardar'),
                   ),
                 ],
               ),
             ],
           ),
         ),
       ),
    );
  }
}

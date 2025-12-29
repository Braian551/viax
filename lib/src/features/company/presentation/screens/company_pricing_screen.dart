import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';

class CompanyPricingTab extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyPricingTab({super.key, required this.user});

  @override
  State<CompanyPricingTab> createState() => _CompanyPricingTabState();
}

class _CompanyPricingTabState extends State<CompanyPricingTab>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pricingConfigs = [];
  Map<String, dynamic>? _empresaInfo;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPricing();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _pricingConfigs = List<Map<String, dynamic>>.from(data['data']['precios'] ?? []);
            _empresaInfo = data['data']['empresa'];
            _isLoading = false;
          });
          _fadeController.forward();
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadPricing,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            // Admin Commission Info Card
            if (_empresaInfo != null) _buildAdminCommissionCard(isDark),
            const SizedBox(height: 20),

            // Balance Card
            if (_empresaInfo != null) _buildBalanceCard(isDark),
            const SizedBox(height: 24),

            // Section Header
            Row(
              children: [
                Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Tus Tarifas',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pricing Cards
            if (_pricingConfigs.isEmpty)
              _buildEmptyState()
            else
              ...List.generate(_pricingConfigs.length, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildPricingCard(_pricingConfigs[index], isDark),
                        ),
                      ),
                    );
                  },
                );
              }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando tarifas...',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Error desconocido'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadPricing,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay tarifas configuradas',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCommissionCard(bool isDark) {
    final comisionAdmin = _empresaInfo?['comision_admin_porcentaje'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primaryDark.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.percent_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comisión Plataforma',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${comisionAdmin.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'de tu comisión a conductores',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    final saldo = _empresaInfo?['saldo_pendiente'] ?? 0.0;
    final hasDebt = saldo > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasDebt
              ? [AppColors.warning.withValues(alpha: 0.15), AppColors.warning.withValues(alpha: 0.05)]
              : [AppColors.success.withValues(alpha: 0.15), AppColors.success.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasDebt
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (hasDebt ? AppColors.warning : AppColors.success).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasDebt ? Icons.account_balance_wallet_outlined : Icons.check_circle_outline,
              color: hasDebt ? AppColors.warning : AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDebt ? 'Saldo Pendiente' : 'Cuenta al día',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${saldo.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: hasDebt ? AppColors.warning : AppColors.success,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Map<String, dynamic> config, bool isDark) {
    final tipo = config['tipo_vehiculo'];
    final icon = _vehicleTypeIcons[tipo] ?? Icons.local_shipping_rounded;
    final nombre = _vehicleTypeNames[tipo] ?? tipo?.toString().toUpperCase() ?? 'Vehículo';
    final isGlobal = config['es_global'] == true || config['heredado'] == true;

    return GestureDetector(
      onTap: () => _showEditSheet(config),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isGlobal)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Usando tarifa estándar',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildDataRow('Tarifa Base', '\$${_formatNumber(config['tarifa_base'])}', isDark),
                  _buildDataRow('Costo/Km', '\$${_formatNumber(config['costo_por_km'])}', isDark, highlight: true),
                  _buildDataRow('Costo/Min', '\$${_formatNumber(config['costo_por_minuto'])}', isDark, highlight: true),
                  _buildDataRow('Mínimo', '\$${_formatNumber(config['tarifa_minima'])}', isDark),
                  const SizedBox(height: 8),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                  const SizedBox(height: 8),
                  _buildDataRow('Recargo H. Pico', '${config['recargo_hora_pico'] ?? 0}%', isDark, color: AppColors.warning),
                  _buildDataRow('Rec. Nocturno', '${config['recargo_nocturno'] ?? 0}%', isDark, color: const Color(0xFF5E5CE6)),
                  _buildDataRow('Tu Comisión', '${config['comision_plataforma'] ?? 0}%', isDark, color: AppColors.success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, bool isDark, {Color? color, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Container(
            padding: highlight ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4) : EdgeInsets.zero,
            decoration: highlight
                ? BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Text(
              value,
              style: TextStyle(
                color: color ?? (highlight ? AppColors.primary : Theme.of(context).colorScheme.onSurface),
                fontSize: highlight ? 15 : 14,
                fontWeight: FontWeight.w600,
              ),
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

  Future<void> _showEditSheet(Map<String, dynamic> config) async {
    final controllers = {
      'tarifa_base': TextEditingController(text: config['tarifa_base']?.toString() ?? '0'),
      'tarifa_minima': TextEditingController(text: config['tarifa_minima']?.toString() ?? '0'),
      'tarifa_maxima': TextEditingController(text: config['tarifa_maxima']?.toString() ?? ''),
      'costo_por_km': TextEditingController(text: config['costo_por_km']?.toString() ?? '0'),
      'costo_por_minuto': TextEditingController(text: config['costo_por_minuto']?.toString() ?? '0'),
      'recargo_hora_pico': TextEditingController(text: config['recargo_hora_pico']?.toString() ?? '0'),
      'recargo_nocturno': TextEditingController(text: config['recargo_nocturno']?.toString() ?? '0'),
      'recargo_festivo': TextEditingController(text: config['recargo_festivo']?.toString() ?? '0'),
      'descuento_distancia_larga': TextEditingController(text: config['descuento_distancia_larga']?.toString() ?? '0'),
      'umbral_km_descuento': TextEditingController(text: config['umbral_km_descuento']?.toString() ?? '15'),
      'comision_plataforma': TextEditingController(text: config['comision_plataforma']?.toString() ?? '0'),
      'distancia_minima': TextEditingController(text: config['distancia_minima']?.toString() ?? '1'),
      'distancia_maxima': TextEditingController(text: config['distancia_maxima']?.toString() ?? '50'),
      'tiempo_espera_gratis': TextEditingController(text: config['tiempo_espera_gratis']?.toString() ?? '3'),
      'costo_tiempo_espera': TextEditingController(text: config['costo_tiempo_espera']?.toString() ?? '0'),
    };

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPricingSheet(
        config: config,
        controllers: controllers,
        vehicleTypeName: _vehicleTypeNames[config['tipo_vehiculo']] ?? config['tipo_vehiculo'] ?? 'Vehículo',
        empresaId: widget.user['empresa_id'] ?? widget.user['id'],
      ),
    );

    for (var controller in controllers.values) {
      controller.dispose();
    }

    if (result == true) {
      _fadeController.reset();
      _loadPricing();
    }
  }
}

class _EditPricingSheet extends StatefulWidget {
  final Map<String, dynamic> config;
  final Map<String, TextEditingController> controllers;
  final String vehicleTypeName;
  final dynamic empresaId;

  const _EditPricingSheet({
    required this.config,
    required this.controllers,
    required this.vehicleTypeName,
    required this.empresaId,
  });

  @override
  State<_EditPricingSheet> createState() => _EditPricingSheetState();
}

class _EditPricingSheetState extends State<_EditPricingSheet> {
  bool _isSaving = false;
  int _currentSection = 0;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Tarifas', 'icon': Icons.attach_money_rounded},
    {'title': 'Distancia', 'icon': Icons.straighten_rounded},
    {'title': 'Recargos', 'icon': Icons.trending_up_rounded},
    {'title': 'Descuentos', 'icon': Icons.local_offer_rounded},
    {'title': 'Comisión', 'icon': Icons.percent_rounded},
    {'title': 'Espera', 'icon': Icons.timer_rounded},
  ];

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final body = {
        'empresa_id': widget.empresaId,
        'tipo_vehiculo': widget.config['tipo_vehiculo'],
        'tarifa_base': double.tryParse(widget.controllers['tarifa_base']!.text) ?? 0,
        'tarifa_minima': double.tryParse(widget.controllers['tarifa_minima']!.text) ?? 0,
        'tarifa_maxima': widget.controllers['tarifa_maxima']!.text.isEmpty ? null : double.tryParse(widget.controllers['tarifa_maxima']!.text),
        'costo_por_km': double.tryParse(widget.controllers['costo_por_km']!.text) ?? 0,
        'costo_por_minuto': double.tryParse(widget.controllers['costo_por_minuto']!.text) ?? 0,
        'recargo_hora_pico': double.tryParse(widget.controllers['recargo_hora_pico']!.text) ?? 0,
        'recargo_nocturno': double.tryParse(widget.controllers['recargo_nocturno']!.text) ?? 0,
        'recargo_festivo': double.tryParse(widget.controllers['recargo_festivo']!.text) ?? 0,
        'descuento_distancia_larga': double.tryParse(widget.controllers['descuento_distancia_larga']!.text) ?? 0,
        'umbral_km_descuento': double.tryParse(widget.controllers['umbral_km_descuento']!.text) ?? 15,
        'comision_plataforma': double.tryParse(widget.controllers['comision_plataforma']!.text) ?? 0,
        'comision_metodo_pago': 0,
        'distancia_minima': double.tryParse(widget.controllers['distancia_minima']!.text) ?? 1,
        'distancia_maxima': double.tryParse(widget.controllers['distancia_maxima']!.text) ?? 50,
        'tiempo_espera_gratis': int.tryParse(widget.controllers['tiempo_espera_gratis']!.text) ?? 3,
        'costo_tiempo_espera': double.tryParse(widget.controllers['costo_tiempo_espera']!.text) ?? 0,
        'activo': 1,
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Tarifas actualizadas'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          _showError(data['message']);
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error: $e');
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Editar Tarifas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(widget.vehicleTypeName, style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Section Tabs
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final isSelected = _currentSection == index;
                return GestureDetector(
                  onTap: () => setState(() => _currentSection = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_sections[index]['icon'] as IconData, size: 16, color: isSelected ? Colors.white : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          _sections[index]['title'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildCurrentSection(),
              ),
            ),
          ),
          // Buttons
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return Column(key: const ValueKey('tarifas'), children: [
          _buildField('Tarifa Base (\$)', widget.controllers['tarifa_base']!),
          _buildField('Tarifa Mínima (\$)', widget.controllers['tarifa_minima']!),
          _buildField('Tarifa Máxima (\$) - Opcional', widget.controllers['tarifa_maxima']!, optional: true),
        ]);
      case 1:
        return Column(key: const ValueKey('distancia'), children: [
          _buildField('Costo por Km (\$)', widget.controllers['costo_por_km']!),
          _buildField('Costo por Minuto (\$)', widget.controllers['costo_por_minuto']!),
          _buildField('Dist. Mínima (km)', widget.controllers['distancia_minima']!),
          _buildField('Dist. Máxima (km)', widget.controllers['distancia_maxima']!),
        ]);
      case 2:
        return Column(key: const ValueKey('recargos'), children: [
          _buildField('Recargo Hora Pico (%)', widget.controllers['recargo_hora_pico']!),
          _buildField('Recargo Nocturno (%)', widget.controllers['recargo_nocturno']!),
          _buildField('Recargo Festivo (%)', widget.controllers['recargo_festivo']!),
        ]);
      case 3:
        return Column(key: const ValueKey('descuentos'), children: [
          _buildField('Desc. Dist. Larga (%)', widget.controllers['descuento_distancia_larga']!),
          _buildField('Umbral Desc. (km)', widget.controllers['umbral_km_descuento']!),
        ]);
      case 4:
        return Column(key: const ValueKey('comision'), children: [
          _buildField('Tu Comisión a Conductores (%)', widget.controllers['comision_plataforma']!),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Esta es la comisión que cobras a tus conductores por cada viaje.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ]);
      case 5:
        return Column(key: const ValueKey('espera'), children: [
          _buildField('Espera Gratis (min)', widget.controllers['tiempo_espera_gratis']!),
          _buildField('Costo/Min Extra (\$)', widget.controllers['costo_tiempo_espera']!),
        ]);
      default:
        return const SizedBox();
    }
  }

  Widget _buildField(String label, TextEditingController controller, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(optional ? r'^(\d+\.?\d{0,2})?' : r'^\d+\.?\d{0,2}'))],
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';
import '../widgets/pricing/company_pricing_card.dart';
import '../widgets/pricing/company_pricing_sheet.dart';

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

  // Note: vehicle names/icons are also in CompanyPricingCard,
  // but we keep names here for passing to EditSheet if needed (or use static from Card if public)
  // Actually CompanyPricingCard handles presentation. EditSheet needs name string.
  final Map<String, String> _vehicleTypeNames = {
    'moto': 'Moto',
    'motocarro': 'Motocarro',
    'taxi': 'Taxi',
    'carro': 'Carro',
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
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/pricing.php?empresa_id=$empresaId',
      );
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _pricingConfigs = List<Map<String, dynamic>>.from(
              data['data']['precios'] ?? [],
            );
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

    if (_isLoading) return _buildShimmerLoading();
    if (_errorMessage != null) return _buildErrorState();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadPricing,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            // Admin Commission Info Card
            // Summary Section (Commission & Balance)
            if (_empresaInfo != null) _buildSummarySection(isDark),
            const SizedBox(height: 24),

            // Section Header
            Row(
              children: [
                Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
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
                          child: CompanyPricingCard(
                            config: _pricingConfigs[index],
                            onTap: () => _showEditSheet(_pricingConfigs[index]),
                          ),
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

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Shimmer for Summary Cards (Row)
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.withValues(alpha: 0.1),
                highlightColor: Colors.grey.withValues(alpha: 0.05),
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.withValues(alpha: 0.1),
                highlightColor: Colors.grey.withValues(alpha: 0.05),
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        // Shimmer for Pricing Cards
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.withValues(alpha: 0.1),
              highlightColor: Colors.grey.withValues(alpha: 0.05),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildSummarySection(bool isDark) {
    final comisionAdmin = _empresaInfo?['comision_admin_porcentaje'] ?? 0.0;
    final saldo = _empresaInfo?['saldo_pendiente'] ?? 0.0;
    final hasDebt = saldo > 0;

    return Row(
      children: [
        // Commission Card
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: 'Comisión',
            value: '${comisionAdmin.toStringAsFixed(1)}%',
            subtitle: 'Plataforma',
            icon: Icons.percent_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 16),
        // Balance Card
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: hasDebt ? 'Pendiente' : 'Al día',
            value: '\$${saldo.toStringAsFixed(0)}',
            subtitle: hasDebt ? 'Saldo' : 'Cuenta',
            icon: hasDebt
                ? Icons.priority_high_rounded
                : Icons.check_circle_outline_rounded,
            color: hasDebt ? AppColors.warning : AppColors.success,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet(Map<String, dynamic> config) async {
    final controllers = {
      'tarifa_base': TextEditingController(
        text: config['tarifa_base']?.toString() ?? '0',
      ),
      'tarifa_minima': TextEditingController(
        text: config['tarifa_minima']?.toString() ?? '0',
      ),
      'tarifa_maxima': TextEditingController(
        text: config['tarifa_maxima']?.toString() ?? '',
      ),
      'costo_por_km': TextEditingController(
        text: config['costo_por_km']?.toString() ?? '0',
      ),
      'costo_por_minuto': TextEditingController(
        text: config['costo_por_minuto']?.toString() ?? '0',
      ),
      'recargo_hora_pico': TextEditingController(
        text: config['recargo_hora_pico']?.toString() ?? '0',
      ),
      'recargo_nocturno': TextEditingController(
        text: config['recargo_nocturno']?.toString() ?? '0',
      ),
      'recargo_festivo': TextEditingController(
        text: config['recargo_festivo']?.toString() ?? '0',
      ),
      'descuento_distancia_larga': TextEditingController(
        text: config['descuento_distancia_larga']?.toString() ?? '0',
      ),
      'umbral_km_descuento': TextEditingController(
        text: config['umbral_km_descuento']?.toString() ?? '15',
      ),
      'comision_plataforma': TextEditingController(
        text: config['comision_plataforma']?.toString() ?? '0',
      ),
      'distancia_minima': TextEditingController(
        text: config['distancia_minima']?.toString() ?? '1',
      ),
      'distancia_maxima': TextEditingController(
        text: config['distancia_maxima']?.toString() ?? '50',
      ),
      'tiempo_espera_gratis': TextEditingController(
        text: config['tiempo_espera_gratis']?.toString() ?? '3',
      ),
      'costo_tiempo_espera': TextEditingController(
        text: config['costo_tiempo_espera']?.toString() ?? '0',
      ),
    };

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: CompanyPricingSheet(
          config: config,
          controllers: controllers,
          vehicleTypeName:
              _vehicleTypeNames[config['tipo_vehiculo']] ??
              config['tipo_vehiculo'] ??
              'Vehículo',
          empresaId: widget.user['empresa_id'] ?? widget.user['id'],
        ),
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

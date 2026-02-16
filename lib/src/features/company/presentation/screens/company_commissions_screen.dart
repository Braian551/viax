import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'company_financial_history_sheet.dart';

class CompanyCommissionsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyCommissionsScreen({super.key, required this.user});

  @override
  State<CompanyCommissionsScreen> createState() => _CompanyCommissionsScreenState();
}

class _CompanyCommissionsScreenState extends State<CompanyCommissionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _debtors = [];
  Map<String, dynamic>? _resumen;
  String? _errorMessage;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadDebtors();
  }

  Future<void> _loadDebtors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final empresaId = widget.user['empresa_id'] ?? widget.user['id'];
      final url = Uri.parse('${AppConfig.baseUrl}/company/get_debtors.php?empresa_id=$empresaId');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _debtors = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _resumen = data['resumen'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Error al cargar datos';
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showFinancialHistory(Map<String, dynamic> conductor) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => DriverFinancialHistorySheet(
          driver: conductor,
          onPaymentRegistered: () {
            _loadDebtors(); // Reload main list
          },
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Comisiones'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDebtors,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _errorMessage != null
              ? _buildError()
              : _buildContent(isDark),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.withOpacity(0.1),
          highlightColor: Colors.grey.withOpacity(0.05),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Error desconocido'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDebtors,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final totalDeuda = _resumen?['deuda_total_empresa'] ?? 0;

    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deuda Total',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(totalDeuda),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_debtors.length} conductores',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Driver List
        Expanded(
          child: _debtors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
                      const SizedBox(height: 16),
                      const Text('No hay deudas pendientes 🎉', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _debtors.length,
                  itemBuilder: (context, index) {
                    final debtor = _debtors[index];
                    return _buildDebtorCard(debtor, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDebtorCard(Map<String, dynamic> debtor, bool isDark) {
    final nombre = '${debtor['nombre']} ${debtor['apellido'] ?? ''}';
    final deuda = double.tryParse(debtor['deuda_actual']?.toString() ?? '0') ?? 0;
    final totalComision = double.tryParse(debtor['total_comision']?.toString() ?? '0') ?? 0;
    final totalPagado = double.tryParse(debtor['total_pagado']?.toString() ?? '0') ?? 0;
    final hasDebt = deuda > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDebt ? Colors.orange.withOpacity(0.4) : AppColors.success.withOpacity(0.3),
          width: hasDebt ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFinancialHistory(debtor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: (hasDebt ? Colors.orange : AppColors.success).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                      style: TextStyle(
                        color: hasDebt ? Colors.orange : AppColors.success,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Comisión: ${_currencyFormat.format(totalComision)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• Pagado: ${_currencyFormat.format(totalPagado)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Debt Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hasDebt ? _currencyFormat.format(deuda) : 'Al día',
                      style: TextStyle(
                        color: hasDebt ? Colors.orange : AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: hasDebt ? 16 : 14,
                      ),
                    ),
                    if (hasDebt)
                      const Text(
                        'Debe',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                  ],
                ),
                if (hasDebt) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: Colors.orange.withOpacity(0.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

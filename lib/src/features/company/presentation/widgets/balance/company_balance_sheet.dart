import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Sheet para mostrar el historial de balance de la empresa con la plataforma
/// Muestra: comisión %, saldo pendiente, historial de cargos y pagos
class CompanyBalanceSheet extends StatefulWidget {
  final int empresaId;

  const CompanyBalanceSheet({
    super.key,
    required this.empresaId,
  });

  @override
  State<CompanyBalanceSheet> createState() => _CompanyBalanceSheetState();
}

class _CompanyBalanceSheetState extends State<CompanyBalanceSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/get_balance.php?empresa_id=${widget.empresaId}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _data = data['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['message'] ?? 'Error al cargar datos';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance con Plataforma',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Historial de comisiones y pagos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadBalance,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error ?? 'Error desconocido'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadBalance,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final empresa = _data?['empresa'];
    final resumen = _data?['resumen'];
    final movimientos = List<Map<String, dynamic>>.from(_data?['ultimos_movimientos'] ?? []);

    final saldoPendiente = double.tryParse(empresa?['saldo_pendiente']?.toString() ?? '0') ?? 0;
    final comision = double.tryParse(empresa?['comision_admin_porcentaje']?.toString() ?? '0') ?? 0;
    final totalCargos = double.tryParse(resumen?['total_cargos']?.toString() ?? '0') ?? 0;
    final totalPagos = double.tryParse(resumen?['total_pagos']?.toString() ?? '0') ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary Cards
        _buildSummaryCards(isDark, saldoPendiente, comision, totalCargos, totalPagos),
        
        const SizedBox(height: 24),

        // Info Text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'La comisión del ${comision.toStringAsFixed(1)}% se aplica sobre cada viaje completado por tus conductores.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // History Section
        Text(
          'Últimos Movimientos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        if (movimientos.isEmpty)
          _buildEmptyMovements()
        else
          ...movimientos.map((mov) => _buildMovementItem(mov, isDark)),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSummaryCards(bool isDark, double saldo, double comision, double cargos, double pagos) {
    return Column(
      children: [
        // Main Balance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: saldo > 0
                  ? [Colors.orange.shade600, Colors.orange.shade800]
                  : [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (saldo > 0 ? Colors.orange : AppColors.success).withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  saldo > 0 ? Icons.account_balance_wallet_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saldo > 0 ? 'Saldo Pendiente' : 'Cuenta al Día',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(saldo),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${comision.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Stats Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                isDark,
                'Total Cargos',
                cargos,
                Icons.arrow_upward_rounded,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                isDark,
                'Total Pagado',
                pagos,
                Icons.arrow_downward_rounded,
                AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(bool isDark, String label, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMovements() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Sin movimientos',
            style: TextStyle(
              color: Colors.grey.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementItem(Map<String, dynamic> mov, bool isDark) {
    final monto = double.tryParse(mov['monto']?.toString() ?? '0') ?? 0;
    final tipo = mov['tipo'] ?? 'cargo';
    final descripcion = mov['descripcion'] ?? '';
    final fecha = mov['creado_en'] ?? '';
    final esCargo = tipo == 'cargo';

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(fecha);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (esCargo ? Colors.orange : AppColors.success).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (esCargo ? Colors.orange : AppColors.success).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              esCargo ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: esCargo ? Colors.orange : AppColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esCargo ? 'Cargo por comisión' : 'Pago recibido',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (parsedDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _dateFormat.format(parsedDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${esCargo ? '+' : '-'}${_currencyFormat.format(monto)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: esCargo ? Colors.orange : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

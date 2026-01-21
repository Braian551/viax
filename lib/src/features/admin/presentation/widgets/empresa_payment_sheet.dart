import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

/// Bottom Sheet para gestionar pagos de una empresa
/// Similar al DriverFinancialHistorySheet pero para empresas
class EmpresaPaymentSheet extends StatefulWidget {
  final int empresaId;
  final String empresaNombre;
  final double saldoPendiente;
  final double comisionPorcentaje;
  final int adminId;
  final VoidCallback? onPaymentRegistered;

  const EmpresaPaymentSheet({
    super.key,
    required this.empresaId,
    required this.empresaNombre,
    required this.saldoPendiente,
    required this.comisionPorcentaje,
    required this.adminId,
    this.onPaymentRegistered,
  });

  @override
  State<EmpresaPaymentSheet> createState() => _EmpresaPaymentSheetState();
}

class _EmpresaPaymentSheetState extends State<EmpresaPaymentSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _movimientos = [];
  double _totalCargos = 0;
  double _totalPagos = 0;
  
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'es_CO');
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.saldoPendiente > 0) {
      _amountController.text = widget.saldoPendiente.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/get_balance.php?empresa_id=${widget.empresaId}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          final resumen = data['data']['resumen'];
          final movs = List<Map<String, dynamic>>.from(
            data['data']['ultimos_movimientos'] ?? [],
          );
          
          setState(() {
            _movimientos = movs;
            _totalCargos = double.tryParse(resumen?['total_cargos']?.toString() ?? '0') ?? 0;
            _totalPagos = double.tryParse(resumen?['total_pagos']?.toString() ?? '0') ?? 0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading empresa balance: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registrarPago() async {
    final monto = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    
    if (monto <= 0) {
      CustomSnackbar.showError(context, message: 'Ingrese un monto válido');
      return;
    }

    if (monto > widget.saldoPendiente) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Monto Mayor'),
          content: Text(
            'El monto (${_currencyFormat.format(monto)}) es mayor que el saldo pendiente '
            '(${_currencyFormat.format(widget.saldoPendiente)}). ¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payments_rounded, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            const Text('Confirmar Pago'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empresa: ${widget.empresaNombre}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currencyFormat.format(monto),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Confirmar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await AdminService.registrarPagoEmpresa(
        empresaId: widget.empresaId,
        monto: monto,
        adminId: widget.adminId,
        notas: 'Pago registrado por admin',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        CustomSnackbar.showSuccess(context, message: 'Pago registrado correctamente');
        widget.onPaymentRegistered?.call();
        Navigator.pop(context); // Close sheet
      } else {
        CustomSnackbar.showError(context, message: result['message'] ?? 'Error al registrar pago');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      CustomSnackbar.showError(context, message: 'Error: $e');
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
            child: Column(
              children: [
                // Logo / Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.empresaNombre.isNotEmpty 
                          ? widget.empresaNombre[0].toUpperCase() 
                          : 'E',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.empresaNombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '${widget.comisionPorcentaje.toStringAsFixed(1)}% comisión',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 16),
                
                // Saldo card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.saldoPendiente > 0
                          ? [Colors.orange.shade600, Colors.orange.shade800]
                          : [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.saldoPendiente > 0 ? 'Saldo Pendiente' : 'Cuenta al Día',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(widget.saldoPendiente),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Stats row
                Row(
                  children: [
                    Expanded(child: _buildStatItem('Total Cargos', _totalCargos, Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatItem('Total Pagado', _totalPagos, AppColors.success)),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // Header de movimientos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Últimos Movimientos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lista de movimientos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _movimientos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Sin movimientos', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _movimientos.length,
                        itemBuilder: (context, index) => _buildMovimientoItem(_movimientos[index], isDark),
                      ),
          ),

          // Payment Area
          if (widget.saldoPendiente > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Monto a registrar',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _registrarPago,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Registrar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                label.contains('Cargos') ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(value),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimientoItem(Map<String, dynamic> mov, bool isDark) {
    final monto = double.tryParse(mov['monto']?.toString() ?? '0') ?? 0;
    final tipo = mov['tipo'] ?? 'cargo';
    final descripcion = mov['descripcion'] ?? '';
    final fecha = mov['creado_en'] ?? '';
    final esPago = tipo == 'pago';

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
          color: (esPago ? AppColors.success : Colors.orange).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (esPago ? AppColors.success : Colors.orange).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              esPago ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: esPago ? AppColors.success : Colors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esPago ? 'Pago recibido' : 'Comisión generada',
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
            '${esPago ? '+' : ''}${_currencyFormat.format(monto)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: esPago ? AppColors.success : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

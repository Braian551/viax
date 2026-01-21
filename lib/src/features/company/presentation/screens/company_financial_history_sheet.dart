import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class DriverFinancialHistorySheet extends StatefulWidget {
  final Map<String, dynamic> driver;
  final VoidCallback? onPaymentRegistered;

  const DriverFinancialHistorySheet({
    super.key,
    required this.driver,
    this.onPaymentRegistered,
  });

  @override
  State<DriverFinancialHistorySheet> createState() => _DriverFinancialHistorySheetState();
}

class _DriverFinancialHistorySheetState extends State<DriverFinancialHistorySheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Pre-fill amount with full debt if > 0
    final deuda = double.tryParse(widget.driver['deuda_actual']?.toString() ?? '0') ?? 0;
    if (deuda > 0) {
      _amountController.text = deuda.toStringAsFixed(0);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final conductorId = widget.driver['id'];
      final url = Uri.parse('${AppConfig.baseUrl}/company/get_conductor_transactions.php?conductor_id=$conductorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _transactions = List<Map<String, dynamic>>.from(data['data']);
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registrarPago() async {
    final monto = double.tryParse(_amountController.text) ?? 0;
    if (monto <= 0) {
      CustomSnackbar.showError(context, message: 'Ingrese un monto válido');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Pago'),
        content: Text('¿Registrar pago de ${_currencyFormat.format(monto)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirm != true) return;
    
    // Show local loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final conductorId = int.parse(widget.driver['id'].toString());
      final result = await AdminService.registrarPagoComision(
        adminId: 0,
        conductorId: conductorId,
        monto: monto,
        notas: 'Pago registrado desde historial detallado',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        CustomSnackbar.showSuccess(context, message: 'Pago registrado');
        widget.onPaymentRegistered?.call();
        _amountController.clear();
        _loadHistory(); // Reload to show new payment
      } else {
        CustomSnackbar.showError(context, message: result['message'] ?? 'Error');
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
    final nombre = '${widget.driver['nombre']} ${widget.driver['apellido'] ?? ''}';
    final deuda = double.tryParse(widget.driver['deuda_actual']?.toString() ?? '0') ?? 0;

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
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Deuda Total', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(
                  _currencyFormat.format(deuda),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: deuda > 0 ? Colors.orange : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 32),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu_rounded, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Sin movimientos recientes', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      final isCargo = t['tipo'] == 'cargo'; // Cargo = debt increase (commission)
                      final monto = double.tryParse(t['monto']?.toString() ?? '0') ?? 0;
                      final date = DateTime.tryParse(t['fecha'] ?? '') ?? DateTime.now();
                      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.1),
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isCargo ? Colors.red : AppColors.success).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCargo ? Icons.directions_car_rounded : Icons.payment_rounded,
                                color: isCargo ? Colors.red : AppColors.success,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['descripcion'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                  if (t['detalle'] != null && t['detalle'] != '')
                                    Text(
                                      t['detalle'],
                                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${isCargo ? '-' : '+'}${_currencyFormat.format(monto)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCargo ? Colors.red : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Payment Area
          if (deuda > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                boxShadow: [
                   BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Monto a pagar',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: _registrarPago,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: const Text('Registrar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/company/services/company_debt_payment_service.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/features/admin/presentation/screens/document_viewer_screen.dart';

class DriverFinancialHistorySheet extends StatefulWidget {
  final Map<String, dynamic> driver;
  final int empresaId;
  final int actorUserId;
  final int? initialReportId;
  final VoidCallback? onPaymentRegistered;

  const DriverFinancialHistorySheet({
    super.key,
    required this.driver,
    required this.empresaId,
    required this.actorUserId,
    this.initialReportId,
    this.onPaymentRegistered,
  });

  @override
  State<DriverFinancialHistorySheet> createState() => _DriverFinancialHistorySheetState();
}

class _DriverFinancialHistorySheetState extends State<DriverFinancialHistorySheet> {
  bool _isLoading = true;
  bool _isLoadingReports = false;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _reports = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final TextEditingController _amountController = TextEditingController();
  bool _handledInitialReport = false;
  double _currentDebt = 0;

  @override
  void initState() {
    super.initState();
    _currentDebt = double.tryParse(widget.driver['deuda_actual']?.toString() ?? '0') ?? 0;
    _loadHistory();
    _amountController.addListener(_formatAmountInput);
    // Pre-fill amount with full debt if > 0
    if (_currentDebt > 0) {
      _setAmountValue(_currentDebt);
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_formatAmountInput);
    _amountController.dispose();
    super.dispose();
  }

  double _parseCopInput(String text) {
    final rawDigits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(rawDigits) ?? 0;
  }

  void _setAmountValue(double value) {
    if (value <= 0) {
      _amountController.clear();
      return;
    }
    _amountController.text = formatCurrency(value, withSymbol: false);
  }

  void _formatAmountInput() {
    final rawDigits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawDigits.isEmpty) return;

    final amount = double.tryParse(rawDigits) ?? 0;
    final formatted = formatCurrency(amount, withSymbol: false);
    if (_amountController.text == formatted) return;

    _amountController.value = _amountController.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }

  void _recalculateDebtFromTransactions() {
    double totalCargos = 0;
    double totalAbonos = 0;

    for (final item in _transactions) {
      final monto = double.tryParse(item['monto']?.toString() ?? '0') ?? 0;
      final tipo = item['tipo']?.toString() ?? '';
      if (tipo == 'cargo') {
        totalCargos += monto;
      } else if (tipo == 'abono') {
        totalAbonos += monto;
      }
    }

    final deudaActual = (totalCargos - totalAbonos).clamp(0, double.infinity).toDouble();
    _currentDebt = deudaActual;

    if (deudaActual <= 0) {
      _amountController.clear();
    } else {
      final currentInput = _parseCopInput(_amountController.text);
      if (currentInput <= 0) {
        _setAmountValue(deudaActual);
      }
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
              _recalculateDebtFromTransactions();
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }

    await _loadDebtReports();
  }

  Future<void> _loadDebtReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final conductorId = int.tryParse((widget.driver['id'] ?? '').toString());
      if (conductorId == null) {
        setState(() => _isLoadingReports = false);
        return;
      }

      final response = await CompanyDebtPaymentService.getReports(
        empresaId: widget.empresaId,
        conductorId: conductorId,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(response['data'] ?? []);
        });
        _openInitialReportIfNeeded();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  void _openInitialReportIfNeeded() {
    if (_handledInitialReport) return;

    final targetReportId = widget.initialReportId;
    if (targetReportId == null || targetReportId <= 0) return;

    _handledInitialReport = true;

    final report = _reports.where((item) => _asInt(item['id']) == targetReportId).firstOrNull;
    if (report == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el comprobante solicitado.')),
        );
      }
      return;
    }

    final proofUrl = report['comprobante_url']?.toString();
    if (proofUrl != null && proofUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showProofDialog(proofUrl);
        }
      });
    }
  }

  Future<void> _performReportAction({
    required int reportId,
    required String action,
    String? motivo,
  }) async {
    final result = await CompanyDebtPaymentService.performAction(
      empresaId: widget.empresaId,
      reporteId: reportId,
      action: action,
      actorUserId: widget.actorUserId,
      motivo: motivo,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      CustomSnackbar.showSuccess(context, message: result['message']?.toString() ?? 'Acción completada');
      widget.onPaymentRegistered?.call();
      _loadHistory();
      return;
    }

    CustomSnackbar.showError(context, message: result['message']?.toString() ?? 'No se pudo completar la acción');
  }

  Future<void> _rejectReport(int reportId) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar comprobante'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo de rechazo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rechazar')),
        ],
      ),
    );

    if (confirm != true) return;
    final motivo = controller.text.trim();
    if (motivo.isEmpty) {
      if (!mounted) return;
      CustomSnackbar.showError(context, message: 'Debes indicar el motivo');
      return;
    }

    await _performReportAction(reportId: reportId, action: 'reject', motivo: motivo);
  }

  Future<void> _registrarPago() async {
    final monto = _parseCopInput(_amountController.text);
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
    final deuda = _currentDebt;

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
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildReportsSection(isDark),
                    const SizedBox(height: 18),
                    if (_transactions.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_edu_rounded, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Sin movimientos recientes', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    else
                      ..._transactions.map((t) {
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
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
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
                                color: (isCargo ? Colors.red : AppColors.success).withValues(alpha: 0.1),
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
                    }),
                  ],
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
                    color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildReportsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comprobantes de transferencia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (_isLoadingReports)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else if (_reports.isEmpty)
            const Text('No hay comprobantes reportados para este conductor')
          else
            ..._reports.map((report) {
              final estado = report['estado']?.toString() ?? 'pendiente_revision';
              final reportId = int.tryParse(report['id']?.toString() ?? '') ?? 0;
              final monto = double.tryParse(report['monto_reportado']?.toString() ?? '0') ?? 0;
              final motivo = report['motivo_rechazo']?.toString() ?? '';
              final proofUrl = report['comprobante_url']?.toString();

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Monto: ${_currencyFormat.format(monto)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(estado).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel(estado),
                            style: TextStyle(color: _statusColor(estado), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (proofUrl != null && proofUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showProofDialog(proofUrl),
                        child: Row(
                          children: const [
                            Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text('Ver comprobante', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                    if (motivo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Motivo rechazo: $motivo', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                    const SizedBox(height: 10),
                    if (estado == 'pendiente_revision')
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: reportId <= 0 ? null : () => _performReportAction(reportId: reportId, action: 'approve'),
                              child: const Text('Aprobar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: reportId <= 0 ? null : () => _rejectReport(reportId),
                              child: const Text('Rechazar'),
                            ),
                          ),
                        ],
                      )
                    else if (estado == 'comprobante_aprobado')
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: reportId <= 0 ? null : () => _performReportAction(reportId: reportId, action: 'confirm_payment'),
                          icon: const Icon(Icons.paid_rounded),
                          label: const Text('Confirmar pago final'),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showProofDialog(String url) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          documentUrl: url,
          documentName: 'Comprobante de pago',
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pendiente_revision':
        return 'Pendiente';
      case 'comprobante_aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      case 'pagado_confirmado':
        return 'Pagado';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pendiente_revision':
        return Colors.orange;
      case 'comprobante_aprobado':
        return Colors.blue;
      case 'rechazado':
        return Colors.red;
      case 'pagado_confirmado':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }
}

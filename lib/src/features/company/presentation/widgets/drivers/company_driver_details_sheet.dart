import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/features/company/presentation/widgets/drivers/company_driver_avatar.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class CompanyDriverDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> driver;
  final VoidCallback? onViewDocuments;
  final VoidCallback? onViewCommissions;

  const CompanyDriverDetailsSheet({
    super.key,
    required this.driver,
    this.onViewDocuments,
    this.onViewCommissions,
  });

  @override
  State<CompanyDriverDetailsSheet> createState() =>
      _CompanyDriverDetailsSheetState();
}

class _CompanyDriverDetailsSheetState extends State<CompanyDriverDetailsSheet> {
  bool _isLoadingEarnings = false;
  bool _isLoadingDebt = false;
  Map<String, dynamic>? _earningsData;
  double _companyDebtFromTransactions = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadEarnings();
    _loadCompanyDebt();
  }

  int? _resolveConductorId() {
    return int.tryParse(
      widget.driver['id']?.toString() ??
          widget.driver['usuario_id']?.toString() ??
          '',
    );
  }

  Future<void> _loadCompanyDebt() async {
    final conductorId = _resolveConductorId();
    if (conductorId == null) return;

    setState(() => _isLoadingDebt = true);

    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/company/get_conductor_transactions.php?conductor_id=$conductorId',
      );
      final response = await http.get(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rows = List<Map<String, dynamic>>.from(data['data'] ?? []);

        double totalCargos = 0;
        double totalAbonos = 0;

        for (final item in rows) {
          final monto = double.tryParse(item['monto']?.toString() ?? '0') ?? 0;
          final tipo = item['tipo']?.toString() ?? '';
          if (tipo == 'cargo') {
            totalCargos += monto;
          } else if (tipo == 'abono') {
            totalAbonos += monto;
          }
        }

        final deuda = (totalCargos - totalAbonos).clamp(0, double.infinity).toDouble();
        setState(() => _companyDebtFromTransactions = deuda);
      }
    } catch (e) {
      debugPrint('Error loading company debt: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDebt = false);
    }
  }

  Future<void> _loadEarnings() async {
    final conductorId = _resolveConductorId();
    if (conductorId == null) return;

    setState(() => _isLoadingEarnings = true);

    try {
      final response = await AdminService.getConductorEarnings(
        conductorId: conductorId,
      );
      if (mounted && response['success'] == true) {
        setState(() => _earningsData = response['ganancias']);
      }
    } catch (e) {
      debugPrint('Error loading earnings: $e');
    } finally {
      if (mounted) setState(() => _isLoadingEarnings = false);
    }
  }

  Future<void> _registrarPago(double deuda) async {
    final conductorId = _resolveConductorId();
    if (conductorId == null) return;

    final controller = TextEditingController(text: formatCurrency(deuda, withSymbol: false));

    void formatCopInput() {
      final rawDigits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (rawDigits.isEmpty) return;
      final amount = double.tryParse(rawDigits) ?? 0;
      final formatted = formatCurrency(amount, withSymbol: false);
      if (formatted == controller.text) return;
      controller.value = controller.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
        composing: TextRange.empty,
      );
    }

    controller.addListener(formatCopInput);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago de Comisión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese el monto que el conductor está pagando:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto (COP)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar Pago'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final monto = double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (monto <= 0) return;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final result = await AdminService.registrarPagoComision(
          adminId: 0, // 0 or null, backend handles it
          conductorId: conductorId,
          monto: monto,
          notas: 'Pago registrado desde panel empresa',
        );

        if (!mounted) return;
        Navigator.pop(context); // Cerrar loading

        if (result['success'] == true) {
          CustomSnackbar.showSuccess(
            context,
            message: 'Pago registrado correctamente',
          );
          _loadEarnings();
          _loadCompanyDebt();
        } else {
          CustomSnackbar.showError(
            context,
            message: result['message'] ?? 'Error al registrar pago',
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Cerrar loading
        CustomSnackbar.showError(context, message: 'Error: $e');
      }
    }

    controller.removeListener(formatCopInput);
    controller.dispose();
  }

  Widget _buildEarningsCard(bool isDark) {
    if (_isLoadingEarnings || _isLoadingDebt) {
      return Container(
        height: 110,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final earningsDebt =
      double.tryParse(_earningsData?['comision_adeudada']?.toString() ?? '0') ?? 0.0;
    final listDebt =
      double.tryParse(widget.driver['deuda_actual']?.toString() ?? '0') ?? 0.0;

    // Prioridad: deuda calculada desde transacciones de empresa (más confiable),
    // luego deuda de endpoint de ganancias y finalmente deuda de la lista.
    double debt = _companyDebtFromTransactions;
    if (earningsDebt > debt) debt = earningsDebt;
    if (listDebt > debt) debt = listDebt;

    final hasDebt = debt > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDebt
              ? Colors.orange.withValues(alpha: 0.5)
              : AppColors.success.withValues(alpha: 0.5),
          width: hasDebt ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasDebt ? Colors.orange : AppColors.success).withValues(
              alpha: 0.1,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hasDebt ? Colors.orange : AppColors.success)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasDebt ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: hasDebt ? Colors.orange : AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comisión Adeudada',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(debt),
                      style: TextStyle(
                        color: hasDebt ? Colors.orange : AppColors.success,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasDebt) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _registrarPago(debt),
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Registrar Pago'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nombre =
        '${widget.driver['nombre']} ${widget.driver['apellido'] ?? ''}';
    final email = widget.driver['email'] ?? 'Sin email';
    final telefono = widget.driver['telefono'] ?? 'Sin teléfono';
    final estado = widget.driver['estado_verificacion'] ?? 'pendiente';
    final rawDate =
        widget.driver['fecha_registro'] ?? widget.driver['created_at'];
    String fechaRegistro;
    if (rawDate != null) {
      try {
        final date = DateTime.parse(rawDate.toString());
        fechaRegistro =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (e) {
        fechaRegistro = rawDate.toString();
      }
    } else {
      fechaRegistro = 'Fecha desconocida';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar Large
                  CompanyDriverAvatar(
                    name: nombre,
                    photoKey:
                        (widget.driver['foto_perfil'] ??
                                widget.driver['fotoPerfil'])
                            ?.toString(),
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombre,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Commission / Earnings Card (New)
                  _buildEarningsCard(isDark),

                  // Info Grid
                  _buildInfoRow(
                    context,
                    Icons.phone_rounded,
                    'Teléfono',
                    telefono,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  _buildInfoRow(
                    context,
                    Icons.verified_user_rounded,
                    'Estado',
                    estado.toUpperCase(),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  _buildInfoRow(
                    context,
                    Icons.calendar_today_rounded,
                    'Registrado',
                    fechaRegistro,
                  ),

                  const SizedBox(height: 32),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          widget.onViewCommissions ??
                          () {
                            Navigator.pop(context);
                          },
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('Ver Historial Financiero'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          widget.onViewDocuments ??
                          () {
                            Navigator.pop(context);
                          },
                      icon: const Icon(Icons.folder_shared_rounded),
                      label: const Text('Ver Documentos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

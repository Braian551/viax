import 'dart:io';

import 'package:flutter/material.dart';
import 'package:viax/src/features/conductor/presentation/widgets/document_upload_widget.dart';
import 'package:viax/src/features/company/services/company_platform_payment_service.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_area.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/dialogs/critical_action_dialog.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

/// Pantalla para que la empresa pague su deuda con la plataforma (admin).
/// Replica el flujo de ConductorDebtPaymentScreen pero para empresa→admin.
class CompanyPlatformPaymentScreen extends StatefulWidget {
  final int empresaId;
  final int userId;
  final Map<String, dynamic> contextData;

  const CompanyPlatformPaymentScreen({
    super.key,
    required this.empresaId,
    required this.userId,
    required this.contextData,
  });

  @override
  State<CompanyPlatformPaymentScreen> createState() =>
      _CompanyPlatformPaymentScreenState();
}

class _CompanyPlatformPaymentScreenState
    extends State<CompanyPlatformPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();
  File? _comprobanteFile;
  bool _isSubmitting = false;
  bool _isFormattingMonto = false;
  bool _isLoadingDebt = false;
  double _resolvedDebt = 0;
  late Map<String, dynamic> _contextData;

  @override
  void initState() {
    super.initState();
    _contextData = Map<String, dynamic>.from(widget.contextData);
    _resolvedDebt = double.tryParse(
            _contextData['deuda_actual']?.toString() ?? '0') ??
        0;
    _prefillAmountWithDebt(_resolvedDebt);
    _montoController.addListener(_formatMontoAsCop);
    _refreshResolvedDebt();
  }

  @override
  void dispose() {
    _montoController.removeListener(_formatMontoAsCop);
    _montoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // ─── Formato COP ───
  void _formatMontoAsCop() {
    if (_isFormattingMonto) return;
    final rawDigits =
        _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawDigits.isEmpty) return;

    final value = double.tryParse(rawDigits) ?? 0;
    final formatted = formatCurrency(value, withSymbol: false);
    if (_montoController.text == formatted) return;

    _isFormattingMonto = true;
    _montoController.value = _montoController.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
    _isFormattingMonto = false;
  }

  double _parseMontoCop() {
    final rawDigits =
        _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(rawDigits) ?? 0;
  }

  void _prefillAmountWithDebt(double debt) {
    if (debt <= 0) return;
    final formatted = formatCurrency(debt, withSymbol: false);
    _isFormattingMonto = true;
    _montoController.text = formatted;
    _isFormattingMonto = false;
  }

  // ─── Resolver deuda desde servidor ───
  Future<void> _refreshResolvedDebt() async {
    setState(() => _isLoadingDebt = true);
    try {
      final result = await CompanyPlatformPaymentService.getDebtContext(
        empresaId: widget.empresaId,
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final serverDebt =
            double.tryParse(data['deuda_actual']?.toString() ?? '0') ?? 0;
        if (mounted) {
          setState(() {
            _contextData = data;
            if (serverDebt > _resolvedDebt) {
              _resolvedDebt = serverDebt;
            }
            if (_resolvedDebt > 0 && _parseMontoCop() <= 0) {
              _prefillAmountWithDebt(_resolvedDebt);
            }
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingDebt = false);
  }

  // ─── Enviar comprobante ───
  Future<void> _submit() async {
    final cuentaTransferencia =
        _contextData['cuenta_transferencia'] as Map<String, dynamic>? ?? {};
    final hasCuenta = cuentaTransferencia['configurada'] == true;
    final estadoReporte = (_contextData['estado_reporte'] ?? 'sin_reporte').toString();
    final bloqueaEnvio =
        estadoReporte == 'pendiente_revision' ||
        estadoReporte == 'comprobante_aprobado';

    if (!_formKey.currentState!.validate()) return;
    if (bloqueaEnvio) {
      CustomSnackbar.show(
        context,
        message:
            'Ya tienes un comprobante en proceso de revisión. Espera el nuevo estado para enviar otro.',
        type: SnackbarType.warning,
      );
      return;
    }
    if (!hasCuenta) {
      CustomSnackbar.show(
        context,
        message:
            'La plataforma aún no tiene cuenta o Nequi configurado para recibir pagos.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (_comprobanteFile == null) {
      CustomSnackbar.show(
        context,
        message: 'Adjunta un comprobante de pago',
        type: SnackbarType.warning,
      );
      return;
    }

    final confirmed = await CriticalActionDialog.show(
      context,
      title: 'Enviar comprobante',
      message:
          'Verifica monto y archivo antes de enviar. Este reporte será revisado por el administrador.',
      confirmText: 'Sí, enviar',
      icon: Icons.send_rounded,
    );
    if (!confirmed) return;

    final monto = _parseMontoCop();
    if (monto <= 0) {
      CustomSnackbar.show(
        context,
        message: 'Ingresa un monto válido',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result =
          await CompanyPlatformPaymentService.submitPaymentProof(
        empresaId: widget.empresaId,
        userId: widget.userId,
        monto: monto,
        comprobante: _comprobanteFile!,
        observaciones: _observacionesController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        CustomSnackbar.show(
          context,
          message: 'Comprobante enviado correctamente',
          type: SnackbarType.success,
        );
        Navigator.of(context).pop(true);
      } else {
        CustomSnackbar.show(
          context,
          message: result['message'] ?? 'Error al enviar',
          type: SnackbarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickComprobante() async {
    final filePath = await DocumentPickerHelper.pickDocument(
      context: context,
      documentType: DocumentType.any,
    );
    if (filePath == null || !mounted) return;
    setState(() => _comprobanteFile = File(filePath));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cuentaTransferencia =
      _contextData['cuenta_transferencia'] as Map<String, dynamic>? ??
            {};
    final hasCuenta = cuentaTransferencia['configurada'] == true;
    final reporteActual =
      _contextData['reporte_actual'] as Map<String, dynamic>? ?? {};
    final estadoReporte =
      (_contextData['estado_reporte'] ?? 'sin_reporte').toString();
    final bloqueaEnvio =
        estadoReporte == 'pendiente_revision' ||
        estadoReporte == 'comprobante_aprobado';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Pagar deuda plataforma'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Resumen de deuda ───
              _buildDebtSummaryCard(isDark),
              const SizedBox(height: 20),

              if (!hasCuenta) ...[
                _buildSafetyBanner(
                  isDark,
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.error,
                  text:
                      'No hay cuenta de recaudo configurada por el administrador. Espera antes de transferir dinero.',
                ),
                const SizedBox(height: 16),
              ],

              if (estadoReporte != 'sin_reporte') ...[
                _buildSafetyBanner(
                  isDark,
                  icon: Icons.schedule_rounded,
                  color: AppColors.warning,
                  text:
                      'Estado del último comprobante: ${estadoReporte.replaceAll('_', ' ')}',
                ),
                if ((reporteActual['motivo_rechazo'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Motivo rechazo: ${reporteActual['motivo_rechazo']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.orangeAccent : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              if (bloqueaEnvio) ...[
                _buildSafetyBanner(
                  isDark,
                  icon: Icons.lock_clock_rounded,
                  color: AppColors.primary,
                  text:
                      'Tu comprobante está en proceso de revisión. No puedes enviar otro hasta que el administrador cambie el estado.',
                ),
                const SizedBox(height: 16),
              ],

              // ─── Cuenta destino ───
              if (hasCuenta) ...[
                _buildSectionTitle('Cuenta de transferencia', isDark),
                const SizedBox(height: 8),
                _buildTransferAccountCard(cuentaTransferencia, isDark),
                const SizedBox(height: 20),
              ],

              // ─── Monto ───
              _buildSectionTitle('Monto a pagar', isDark),
              const SizedBox(height: 8),
              AuthTextField(
                controller: _montoController,
                label: 'Monto (COP)',
                hintText: 'Ej: 150.000',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'Ingresa el monto';
                  if (_parseMontoCop() <= 0) return 'El monto debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Comprobante ───
              _buildSectionTitle('Comprobante de pago', isDark),
              const SizedBox(height: 8),
              DocumentUploadWidget(
                label: 'Adjuntar comprobante',
                subtitle: 'Foto o PDF del comprobante de transferencia',
                filePath: _comprobanteFile?.path,
                acceptedType: DocumentType.any,
                onTap: bloqueaEnvio
                    ? () {
                        CustomSnackbar.show(
                          context,
                          message:
                              'No puedes adjuntar un nuevo comprobante mientras el actual está en revisión.',
                          type: SnackbarType.info,
                        );
                      }
                    : _pickComprobante,
                onRemove: _comprobanteFile == null
                    ? null
                    : () => setState(() => _comprobanteFile = null),
              ),
              const SizedBox(height: 16),

              // ─── Observaciones ───
              _buildSectionTitle('Observaciones (opcional)', isDark),
              const SizedBox(height: 8),
              AuthTextArea(
                controller: _observacionesController,
                label: 'Notas adicionales',
                icon: Icons.notes_rounded,
                helperText: 'Referencia de transferencia, detalles...',
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              // ─── Botón enviar ───
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting || !hasCuenta || bloqueaEnvio ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ))
                      : const Icon(Icons.send_rounded),
                    label: Text(_isSubmitting
                      ? 'Enviando...'
                      : (bloqueaEnvio
                          ? 'Comprobante en revisión'
                          : (hasCuenta ? 'Enviar comprobante' : 'Cuenta no disponible'))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tarjeta de resumen de deuda ───
  Widget _buildDebtSummaryCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Deuda con la plataforma',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isLoadingDebt) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white54,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatCurrency(_resolvedDebt),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Comisión: ${_contextData['comision_porcentaje'] ?? widget.contextData['comision_porcentaje'] ?? 0}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tarjeta de cuenta de transferencia ───
  Widget _buildTransferAccountCard(
      Map<String, dynamic> cuenta, bool isDark) {
    final metodo = (cuenta['metodo_recaudo'] ?? '').toString();
    final isNequi = metodo == 'nequi' ||
      (cuenta['tipo_cuenta'] ?? '').toString().toLowerCase() == 'nequi' ||
      (cuenta['banco_nombre'] ?? '').toString().toLowerCase() == 'nequi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              'Método', isNequi ? 'Nequi' : 'Cuenta bancaria', isDark),
          if (!isNequi) ...[
            _buildInfoRow('Banco', cuenta['banco_nombre'] ?? '-', isDark),
            _buildInfoRow('Tipo', cuenta['tipo_cuenta'] ?? '-', isDark),
            _buildInfoRow('Cuenta', cuenta['numero_cuenta'] ?? '-', isDark),
          ] else
            _buildInfoRow(
                'Número Nequi', cuenta['numero_cuenta'] ?? '-', isDark),
          _buildInfoRow('Titular', cuenta['titular_cuenta'] ?? '-', isDark),
          if ((cuenta['documento_titular'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
                'Documento', cuenta['documento_titular'], isDark),
          if ((cuenta['referencia_transferencia'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
                'Referencia', cuenta['referencia_transferencia'], isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyBanner(
    bool isDark, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: isDark ? Colors.white.withValues(alpha: 0.92) : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:viax/src/features/conductor/presentation/widgets/document_upload_widget.dart';
import 'package:viax/src/features/conductor/services/debt_payment_service.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_area.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class ConductorDebtPaymentScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic> contextData;

  const ConductorDebtPaymentScreen({
    super.key,
    required this.conductorId,
    required this.contextData,
  });

  @override
  State<ConductorDebtPaymentScreen> createState() => _ConductorDebtPaymentScreenState();
}

class _ConductorDebtPaymentScreenState extends State<ConductorDebtPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  File? _comprobanteFile;
  bool _isSubmitting = false;
  bool _isFormattingMonto = false;

  @override
  void initState() {
    super.initState();
    final deuda = double.tryParse(widget.contextData['deuda_actual']?.toString() ?? '0') ?? 0;
    if (deuda > 0) {
      _montoController.text = formatCurrency(deuda, withSymbol: false);
    }
    _montoController.addListener(_formatMontoAsCop);
  }

  @override
  void dispose() {
    _montoController.removeListener(_formatMontoAsCop);
    _montoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _formatMontoAsCop() {
    if (_isFormattingMonto) return;
    final rawDigits = _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (rawDigits.isEmpty) {
      return;
    }

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
    final rawDigits = _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(rawDigits) ?? 0;
  }

  Future<void> _pickProof() async {
    final path = await DocumentPickerHelper.pickDocument(
      context: context,
      documentType: DocumentType.any,
      allowGallery: true,
    );

    if (path == null || path.isEmpty) return;

    setState(() {
      _comprobanteFile = File(path);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = _parseMontoCop();
    if (monto <= 0) {
      CustomSnackbar.showError(context, message: 'Ingresa un monto válido');
      return;
    }

    if (_comprobanteFile == null) {
      CustomSnackbar.showError(context, message: 'Debes adjuntar el comprobante');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await DebtPaymentService.submitPaymentProof(
      conductorId: widget.conductorId,
      monto: monto,
      comprobante: _comprobanteFile!,
      observaciones: _observacionesController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      CustomSnackbar.showSuccess(context, message: result['message']?.toString() ?? 'Comprobante enviado');
      Navigator.pop(context, true);
      return;
    }

    CustomSnackbar.showError(context, message: result['message']?.toString() ?? 'No se pudo enviar el comprobante');
  }

  bool _isImageFile(File file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
      path.endsWith('.heic') ||
      path.endsWith('.heif') ||
      path.endsWith('.jfif');
  }

  String _fileName(File file) => file.path.split(Platform.pathSeparator).last;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  void _showImagePreview(File file) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferCard(
    bool isDark,
    String companyName,
    String banco,
    String tipoCuenta,
    String numeroCuenta,
    String titular,
    String documento,
    String referencia,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.darkShadow : AppColors.lightShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Transferir a $companyName',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Banco', banco),
          _buildInfoRow('Tipo de cuenta', tipoCuenta),
          _buildInfoRow('Número de cuenta', numeroCuenta),
          _buildInfoRow('Titular', titular),
          _buildInfoRow('Documento titular', documento),
          if (referencia.isNotEmpty) _buildInfoRow('Referencia', referencia),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofSection(bool isDark) {
    if (_comprobanteFile == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _pickProof,
          icon: const Icon(Icons.attach_file_rounded),
          label: const Text('Adjuntar comprobante (cámara, galería o archivo)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    final file = _comprobanteFile!;
    final isImage = _isImageFile(file);
    final fileSize = file.existsSync() ? _formatFileSize(file.lengthSync()) : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            GestureDetector(
              onTap: () => _showImagePreview(file),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fileName(file),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            _fileName(file),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            fileSize,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickProof,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Cambiar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _comprobanteFile = null;
                          }),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Quitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cuenta = (widget.contextData['cuenta_transferencia'] as Map<String, dynamic>?) ?? {};
    final empresa = (widget.contextData['empresa'] as Map<String, dynamic>?) ?? {};

    final banco = cuenta['banco_nombre']?.toString() ?? '-';
    final tipoCuenta = cuenta['tipo_cuenta']?.toString() ?? '-';
    final numeroCuenta = cuenta['numero_cuenta']?.toString() ?? '-';
    final titular = cuenta['titular_cuenta']?.toString() ?? '-';
    final documento = cuenta['documento_titular']?.toString() ?? '-';
    final referencia = cuenta['referencia_transferencia']?.toString() ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Pagar deuda'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTransferCard(
                isDark,
                empresa['nombre']?.toString() ?? 'empresa',
                banco,
                tipoCuenta,
                numeroCuenta,
                titular,
                documento,
                referencia,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _montoController,
                label: 'Monto transferido (COP)',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                hintText: 'Ej: 12.500',
                helperText: 'Formato COP con punto de miles (ej: 12.500).',
                validator: (value) {
                  final monto = _parseMontoCop();
                  if (monto <= 0) return 'Ingresa un monto válido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AuthTextArea(
                controller: _observacionesController,
                label: 'Observaciones (opcional)',
                icon: Icons.notes_rounded,
                helperText: 'Puedes agregar detalles de la transferencia.',
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildProofSection(isDark),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_isSubmitting ? 'Enviando...' : 'Enviar comprobante'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

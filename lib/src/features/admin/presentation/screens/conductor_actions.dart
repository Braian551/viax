import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/widgets/dialogs/admin_dialog_helper.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'conductor_historial_sheet.dart';

Future<void> aprobarConductor({
  required BuildContext context,
  required int adminId,
  required Map<String, dynamic> conductor,
  required VoidCallback onSuccess,
}) async {
  final confirm = await AdminDialogHelper.showApprovalConfirmation(
    context,
    conductorName: conductor['nombre_completo'] ?? 'Conductor',
    subtitle: 'Licencia: ${conductor['licencia_conduccion'] ?? 'N/A'}',
  );

  if (confirm == true) {
    // Validar ID primero
    if (conductor['usuario_id'] == null) {
      CustomSnackbar.showError(context, message: 'Error: ID de conductor no válido');
      return;
    }

    // Mostrar loading
    AdminDialogHelper.showLoading(context, message: 'Aprobando conductor...');

    print('DEBUG: aprobarConductor called');
    print('DEBUG: adminId: $adminId (${adminId.runtimeType})');
    print('DEBUG: conductor["usuario_id"]: ${conductor["usuario_id"]} (${conductor["usuario_id"]?.runtimeType})');

    try {
      final response = await AdminService.aprobarConductor(
        adminId: adminId,
        conductorId: int.parse(conductor['usuario_id'].toString()),
      );

      // Cerrar loading
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      // Esperar un poco
      await Future.delayed(const Duration(milliseconds: 100));

      if (!context.mounted) return;

      if (response['success'] == true) {
        CustomSnackbar.showSuccess(context, message: 'Conductor aprobado exitosamente');
        onSuccess();
      } else {
        CustomSnackbar.showError(context, message: response['message'] ?? 'Error al aprobar conductor');
      }
    } catch (e) {
      // Cerrar loading si hay error
      if (Navigator.canPop(context)) Navigator.pop(context);
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) {
        print('DEBUG: Error caught: $e');
        CustomSnackbar.showError(context, message: 'Error al aprobar conductor: $e');
      }
    }
  }
}

Future<void> rechazarConductor({
  required BuildContext context,
  required int adminId,
  required Map<String, dynamic> conductor,
  required VoidCallback onSuccess,
}) async {
  final motivo = await AdminDialogHelper.showRejectionDialog(
    context,
    conductorName: conductor['nombre_completo'] ?? 'Conductor',
  );

  if (motivo != null && motivo.isNotEmpty) {
    // Validar ID primero
    if (conductor['usuario_id'] == null) {
      CustomSnackbar.showError(context, message: 'Error: ID de conductor no válido');
      return;
    }

    // Mostrar loading
    AdminDialogHelper.showLoading(context, message: 'Rechazando conductor...');

    try {
      final response = await AdminService.rechazarConductor(
        adminId: adminId,
        conductorId: int.parse(conductor['usuario_id'].toString()),
        motivo: motivo,
      );

      // Cerrar loading
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      // Esperar un poco
      await Future.delayed(const Duration(milliseconds: 100));

      if (!context.mounted) return;

      if (response['success'] == true) {
        CustomSnackbar.showSuccess(context, message: 'Conductor rechazado');
        onSuccess();
      } else {
        CustomSnackbar.showError(context, message: response['message'] ?? 'Error al rechazar conductor');
      }
    } catch (e) {
      // Cerrar loading si hay error
      if (Navigator.canPop(context)) Navigator.pop(context);
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) {
        CustomSnackbar.showError(context, message: 'Error al rechazar conductor: $e');
      }
    }
  }
}

Future<void> showDocumentHistory({
  required BuildContext context,
  required int adminId,
  required int conductorId,
  required Function(String?, String, {String? tipoArchivo}) onViewDocument,
}) async {
  // Mostrar loading
  AdminDialogHelper.showLoading(context, message: 'Cargando historial...');

  try {
    final response = await AdminService.getDocumentosHistorial(
      adminId: adminId,
      conductorId: conductorId,
    );

    // Cerrar loading primero
    if (Navigator.canPop(context)) Navigator.pop(context);

    // Esperar un poco para que el diálogo se cierre completamente
    await Future.delayed(const Duration(milliseconds: 100));

    if (!context.mounted) return;

    if (response['success'] == true && response['data'] != null) {
      final List<Map<String, dynamic>> historial = 
          List<Map<String, dynamic>>.from(response['data']['historial'] ?? []);

      // Si no hay historial, mostrar alerta
      if (historial.isEmpty) {
        await AdminDialogHelper.showNoHistoryDialog(context);
        return;
      }

      // Mostrar el historial
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ConductorHistorialSheet(
          historial: historial,
          onViewDocument: onViewDocument,
        ),
      );
    } else {
      CustomSnackbar.showError(context, message: response['message'] ?? 'Error al cargar historial');
    }
  } catch (e) {
    // Cerrar loading si hay error
    if (Navigator.canPop(context)) Navigator.pop(context);
    
    // Esperar un poco antes de mostrar el error
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (context.mounted) {
      CustomSnackbar.showError(context, message: 'Error al cargar historial: $e');
    }
  }
}
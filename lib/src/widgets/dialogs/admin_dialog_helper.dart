// lib/src/widgets/dialogs/admin_dialog_helper.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Helper especÃ­fico para diÃ¡logos administrativos con diseÃ±os personalizados
class AdminDialogHelper {
  /// Muestra un diÃ¡logo de confirmaciÃ³n para aprobar conductor
  static Future<bool?> showApprovalConfirmation(
    BuildContext context, {
    required String conductorName,
    String? subtitle,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _AdminConfirmationDialog(
        type: _AdminDialogType.approve,
        title: 'Â¿Aprobar Conductor?',
        conductorName: conductorName,
        subtitle: subtitle,
        confirmText: 'Aprobar',
        cancelText: 'Cancelar',
      ),
    );
  }

  /// Muestra un diÃ¡logo de confirmaciÃ³n para rechazar conductor
  static Future<String?> showRejectionDialog(
    BuildContext context, {
    required String conductorName,
  }) {
    final TextEditingController controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _AdminRejectionDialog(
        conductorName: conductorName,
        motivoController: controller,
      ),
    );
  }

  /// Muestra un diÃ¡logo informativo cuando no hay historial
  static Future<void> showNoHistoryDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _AdminInfoDialog(
        icon: Icons.folder_open_rounded,
        title: 'Sin Historial',
        message: 'Este conductor aÃºn no tiene historial de documentos registrado.',
        tip: 'El historial se genera cuando el conductor sube o actualiza sus documentos.',
      ),
    );
  }

  /// Muestra un diÃ¡logo de carga
  static void showLoading(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFFFFF00)),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AdminDialogType {
  approve,
  // reject, // No se usa actualmente pero se puede usar en el futuro
}

/// DiÃ¡logo de confirmaciÃ³n personalizado para acciones administrativas
class _AdminConfirmationDialog extends StatelessWidget {
  final _AdminDialogType type;
  final String title;
  final String conductorName;
  final String? subtitle;
  final String confirmText;
  final String cancelText;

  const _AdminConfirmationDialog({
    required this.type,
    required this.title,
    required this.conductorName,
    this.subtitle,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = type == _AdminDialogType.approve 
        ? const Color(0xFF11998e) 
        : const Color(0xFFf5576c);
    
    final IconData icon = type == _AdminDialogType.approve
        ? Icons.check_circle_outline_rounded
        : Icons.cancel_outlined;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con icono
            Container(
              padding: const EdgeInsets.only(top: 32, bottom: 20),
              child: Column(
                children: [
                  // Icono con efecto glow
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.3),
                          primaryColor.withValues(alpha: 0.05),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, size: 44, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // TÃ­tulo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // InformaciÃ³n del conductor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            conductorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mensaje de advertencia
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        type == _AdminDialogType.approve
                            ? 'Esta acciÃ³n aprobarÃ¡ al conductor y le permitirÃ¡ empezar a realizar viajes.'
                            : 'Esta acciÃ³n rechazarÃ¡ los documentos del conductor.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botones
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  // BotÃ³n confirmar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // BotÃ³n cancelar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DiÃ¡logo para rechazar conductor con campo de texto
class _AdminRejectionDialog extends StatelessWidget {
  final String conductorName;
  final TextEditingController motivoController;

  const _AdminRejectionDialog({
    required this.conductorName,
    required this.motivoController,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFf5576c).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFf5576c).withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 32, bottom: 20),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFf5576c).withValues(alpha: 0.3),
                          const Color(0xFFf5576c).withValues(alpha: 0.05),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 44,
                        color: Color(0xFFf5576c),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Rechazar Conductor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFf5576c),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Nombre conductor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        conductorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Campo de texto para motivo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motivo del rechazo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: motivoController,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Describe el motivo del rechazo...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFf5576c),
                          width: 1.5,
                        ),
                      ),
                      counterStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botones
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (motivoController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Debes indicar el motivo del rechazo'),
                              backgroundColor: Color(0xFFf5576c),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(motivoController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFf5576c),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Rechazar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DiÃ¡logo informativo personalizado
class _AdminInfoDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? tip;

  const _AdminInfoDialog({
    required this.icon,
    required this.title,
    required this.message,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFFF00).withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 32, bottom: 20),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFFF00).withValues(alpha: 0.2),
                          const Color(0xFFFFFF00).withValues(alpha: 0.05),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, size: 44, color: const Color(0xFFFFFF00)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFFF00),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (tip != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFF00).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Color(0xFFFFFF00),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFF00),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

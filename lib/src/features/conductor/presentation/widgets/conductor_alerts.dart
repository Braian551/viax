import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/conductor_profile_model.dart';

/// Tipo de acción requerida para completar el perfil
enum ProfileAction {
  registerLicense,
  registerVehicle,
  submitVerification,
  completeProfile,
  inReview,
  awaitingApproval,
}

/// Helper function to determine the action type based on profile
ProfileAction getProfileActionType(ConductorProfileModel? profile) {
  if (profile == null) {
    return ProfileAction.completeProfile;
  }

  // Si está en revisión
  if (profile.estadoVerificacion == VerificationStatus.enRevision) {
    return ProfileAction.inReview;
  }

  // Si está aprobado, no necesita hacer nada
  if (profile.estadoVerificacion == VerificationStatus.aprobado && profile.aprobado) {
    return ProfileAction.completeProfile;
  }

  // Si el perfil está completo pero no aprobado (esperando aprobación)
  if (profile.isProfileComplete && !profile.aprobado) {
    return ProfileAction.awaitingApproval;
  }

  // Si no tiene licencia o está incompleta
  if (profile.licencia == null || !profile.licencia!.isComplete) {
    return ProfileAction.registerLicense;
  }

  // Si no tiene vehículo o está incompleto
  if (profile.vehiculo == null || !profile.vehiculo!.isBasicComplete) {
    return ProfileAction.registerVehicle;
  }

  // Si el perfil está completo pero no se ha enviado para verificación
  if (profile.isProfileComplete && 
      profile.estadoVerificacion == VerificationStatus.pendiente) {
    return ProfileAction.submitVerification;
  }

  // Caso por defecto
  return ProfileAction.completeProfile;
}

/// Alert shown when driver profile is incomplete
class ProfileIncompleteAlert extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback? onDismiss;
  final List<String> missingItems;
  final ProfileAction actionType;

  const ProfileIncompleteAlert({
    super.key,
    required this.onComplete,
    this.onDismiss,
    this.missingItems = const [],
    this.actionType = ProfileAction.completeProfile,
  });

  @override
  Widget build(BuildContext context) {
    final buttonText = _getButtonText();
    final title = _getTitle();
    final message = _getMessage();
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                  const Color(0xFF0D0D0D).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFFFF00).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFFF00).withValues(alpha: 0.25),
                          const Color(0xFFFFFF00).withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: const Color(0xFFFFFF00),
                      size: isSmallScreen ? 44 : 52,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 18 : 24),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 22 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 14),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 14 : 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (missingItems.isNotEmpty) ...[
                    SizedBox(height: isSmallScreen ? 14 : 18),
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pendiente:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...missingItems.take(3).map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: Color(0xFFFFFF00),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: isSmallScreen ? 20 : 28),
                  Row(
                    children: [
                      if (onDismiss != null)
                        Expanded(
                          child: TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 16,
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Después',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (onDismiss != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onComplete,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 14 : 16,
                            ),
                            backgroundColor: const Color(0xFFFFFF00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFFFFFF00).withValues(alpha: 0.5),
                          ),
                          child: Text(
                            buttonText,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    switch (actionType) {
      case ProfileAction.registerLicense:
        return 'Licencia';
      case ProfileAction.registerVehicle:
        return 'Vehículo';
      case ProfileAction.submitVerification:
        return 'Mi Perfil';
      case ProfileAction.completeProfile:
        return 'Completar Ahora';
      case ProfileAction.inReview:
        return 'Mi Perfil';
      case ProfileAction.awaitingApproval:
        return 'Ver Perfil';
    }
  }

  String _getTitle() {
    switch (actionType) {
      case ProfileAction.registerLicense:
        return 'Falta tu Licencia';
      case ProfileAction.registerVehicle:
        return 'Falta tu Vehículo';
      case ProfileAction.submitVerification:
        return 'Perfil Listo';
      case ProfileAction.completeProfile:
        return 'Perfil Incompleto';
      case ProfileAction.inReview:
        return 'Verificación en Proceso';
      case ProfileAction.awaitingApproval:
        return 'Esperando Aprobación';
    }
  }

  String _getMessage() {
    switch (actionType) {
      case ProfileAction.registerLicense:
        return 'Necesitas registrar tu licencia de conducción para poder activar tu disponibilidad.';
      case ProfileAction.registerVehicle:
        return 'Necesitas registrar tu vehículo para poder activar tu disponibilidad.';
      case ProfileAction.submitVerification:
        return 'Tu perfil está completo. Envíalo para verificación y podrás empezar a recibir viajes.';
      case ProfileAction.completeProfile:
        return 'Para activar tu disponibilidad y recibir viajes, debes completar tu perfil de conductor.';
      case ProfileAction.inReview:
        return 'Tu documentación está siendo revisada. Te notificaremos cuando el proceso esté completo.';
      case ProfileAction.awaitingApproval:
        return 'Tu perfil está completo y enviado. Un administrador revisará tus documentos pronto y te notificaremos cuando seas aprobado.';
    }
  }

  static Future<bool?> show(
    BuildContext context, {
    List<String> missingItems = const [],
    bool dismissible = true,
    ProfileAction actionType = ProfileAction.completeProfile,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => ProfileIncompleteAlert(
        missingItems: missingItems,
        actionType: actionType,
        onComplete: () => Navigator.of(context).pop(true),
        onDismiss: dismissible ? () => Navigator.of(context).pop(false) : null,
      ),
    );
  }
}

/// Alert for document expiration warning
class DocumentExpiryAlert extends StatelessWidget {
  final String documentName;
  final DateTime expiryDate;
  final VoidCallback onRenew;
  final VoidCallback? onDismiss;

  const DocumentExpiryAlert({
    super.key,
    required this.documentName,
    required this.expiryDate,
    required this.onRenew,
    this.onDismiss,
  });

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 30;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                  const Color(0xFF0D0D0D).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isExpired
                    ? Colors.red.withValues(alpha: 0.4)
                    : Colors.orange.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.25),
                          (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpired ? Icons.error_rounded : Icons.warning_rounded,
                      color: isExpired ? Colors.red : Colors.orange,
                      size: isSmallScreen ? 44 : 52,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 18 : 24),
                  Text(
                    isExpired ? 'Documento Vencido' : 'Documento por Vencer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 22 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 14),
                  Text(
                    isExpired
                        ? 'Tu $documentName ha vencido. No podrás recibir viajes hasta renovarlo.'
                        : 'Tu $documentName vence en $daysUntilExpiry días. Renuévalo pronto.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 14 : 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Vence: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
                      style: TextStyle(
                        color: isExpired ? Colors.red : Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 20 : 28),
                  Row(
                    children: [
                      if (onDismiss != null && !isExpired)
                        Expanded(
                          child: TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 16,
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Después',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (onDismiss != null && !isExpired) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onRenew,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 14 : 16,
                            ),
                            backgroundColor: isExpired ? Colors.red : const Color(0xFFFFFF00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                            shadowColor: (isExpired ? Colors.red : const Color(0xFFFFFF00)).withValues(alpha: 0.5),
                          ),
                          child: Text(
                            'Renovar Ahora',
                            style: TextStyle(
                              color: isExpired ? Colors.white : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String documentName,
    required DateTime expiryDate,
    bool dismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => DocumentExpiryAlert(
        documentName: documentName,
        expiryDate: expiryDate,
        onRenew: () => Navigator.of(context).pop(true),
        onDismiss: dismissible ? () => Navigator.of(context).pop(false) : null,
      ),
    );
  }
}

class ConfirmationAlert extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final Color? accentColor;
  final IconData? icon;

  const ConfirmationAlert({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirmar',
    this.cancelText = 'Cancelar',
    required this.onConfirm,
    this.onCancel,
    this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFFFFFF00);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                  const Color(0xFF0D0D0D).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.25),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: isSmallScreen ? 44 : 52,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 18 : 24),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 22 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 14),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 14 : 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 20 : 28),
                  Row(
                    children: [
                      if (cancelText != null)
                        Expanded(
                          child: TextButton(
                            onPressed: onCancel ?? () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 16,
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              cancelText!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (cancelText != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 14 : 16,
                            ),
                            backgroundColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                            shadowColor: color.withValues(alpha: 0.5),
                          ),
                          child: Text(
                            confirmText,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String? cancelText = 'Cancelar',
    Color? accentColor,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => ConfirmationAlert(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        accentColor: accentColor,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: cancelText != null ? () => Navigator.of(context).pop(false) : null,
      ),
    );
  }
}

/// Trip request modal
class TripRequestModal extends StatefulWidget {
  final Map<String, dynamic> tripData;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const TripRequestModal({
    super.key,
    required this.tripData,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<TripRequestModal> createState() => _TripRequestModalState();
}

class _TripRequestModalState extends State<TripRequestModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        widget.onReject();
        Navigator.of(context).pop();
        return false;
      }
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 24,
      ),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                    const Color(0xFF0D0D0D).withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFFFFF00).withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFFF00).withValues(alpha: 0.25),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timer badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _remainingSeconds <= 10
                                ? [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.15)]
                                : [const Color(0xFFFFFF00).withValues(alpha: 0.3), const Color(0xFFFFFF00).withValues(alpha: 0.15)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: (_remainingSeconds <= 10 ? Colors.red : const Color(0xFFFFFF00)).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: _remainingSeconds <= 10 ? Colors.red : const Color(0xFFFFFF00),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_remainingSeconds seg',
                              style: TextStyle(
                                color: _remainingSeconds <= 10 ? Colors.red : const Color(0xFFFFFF00),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 18 : 24),
                      Text(
                        '¡Nueva Solicitud!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 24 : 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 26),
                      // Customer info
                      _buildInfoCard(
                        icon: Icons.person_rounded,
                        label: 'Pasajero',
                        value: widget.tripData['customerName'] ?? 'Cliente',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.star_rounded,
                        label: 'Calificación',
                        value: '${widget.tripData['customerRating'] ?? '5.0'} ⭐',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.location_on_rounded,
                        label: 'Recogida',
                        value: widget.tripData['pickupAddress'] ?? 'Calle 123',
                        isMultiline: true,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.flag_rounded,
                        label: 'Destino',
                        value: widget.tripData['destinationAddress'] ?? 'Calle 456',
                        isMultiline: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.route_rounded,
                              label: 'Distancia',
                              value: '${widget.tripData['distance'] ?? '5.2'} km',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.attach_money,
                              label: 'Tarifa',
                              value: '\$${widget.tripData['fare'] ?? '15000'}',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 28),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onReject();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 14 : 16,
                                ),
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 8,
                                shadowColor: Colors.red.withValues(alpha: 0.5),
                              ),
                              child: const Text(
                                'Rechazar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onAccept();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 14 : 16,
                                ),
                                backgroundColor: const Color(0xFFFFFF00),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFFFFFF00).withValues(alpha: 0.5),
                              ),
                              child: const Text(
                                'Aceptar Viaje',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFFFF00), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: isMultiline ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> tripData,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (context) => TripRequestModal(
        tripData: tripData,
        onAccept: onAccept,
        onReject: onReject,
      ),
    );
  }
}

/// Earnings notification
class EarningsNotification extends StatelessWidget {
  final double amount;
  final String description;
  final VoidCallback? onTap;

  const EarningsNotification({
    super.key,
    required this.amount,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: 0.2),
              Colors.green.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.attach_money,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+\$${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.green,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Success notification
class SuccessNotification {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Error notification
class ErrorNotification {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

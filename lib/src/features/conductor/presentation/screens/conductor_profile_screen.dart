import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../theme/app_colors.dart';
import '../../providers/conductor_profile_provider.dart';
import '../../models/conductor_profile_model.dart';
import 'license_registration_screen.dart';
import 'vehicle_only_registration_screen.dart';
import 'verification_status_screen.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

class ConductorProfileScreen extends StatefulWidget {
  final int conductorId;
  final bool showBackButton;

  const ConductorProfileScreen({
    super.key,
    required this.conductorId,
    this.showBackButton = true,
  });

  @override
  State<ConductorProfileScreen> createState() => _ConductorProfileScreenState();
}

class _ConductorProfileScreenState extends State<ConductorProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ConductorProfileProvider>(
        context,
        listen: false,
      ).loadProfile(widget.conductorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark),
      body: Consumer<ConductorProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildShimmerLoading(isDark);
          }

          final profile = provider.profile;
          if (profile == null) {
            return _buildErrorView(provider, isDark);
          }

          // Si el conductor está aprobado, mostrar vista de perfil aprobado
          if (profile.aprobado &&
              profile.estadoVerificacion == VerificationStatus.aprobado) {
            return _buildApprovedProfileView(profile, isDark);
          }

          // Si no está aprobado, mostrar vista de verificación
          return _buildVerificationView(profile, provider, isDark);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkBackground : Colors.white).withOpacity(0.8),
            ),
          ),
        ),
      ),
      leading: widget.showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_rounded, 
                color: isDark ? Colors.white : Colors.black87
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      automaticallyImplyLeading: widget.showBackButton,
      title: Text(
        'Mi Perfil',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorView(ConductorProfileProvider provider, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 64),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar el perfil',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87, 
              fontSize: 18
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => provider.loadProfile(widget.conductorId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationView(
    ConductorProfileModel profile, 
    ConductorProfileProvider provider,
    bool isDark
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildCompletionProgress(profile, isDark),
            const SizedBox(height: 32),
            _buildVerificationStatus(profile, isDark),
            const SizedBox(height: 24),
            _buildLicenseSection(profile, isDark),
            const SizedBox(height: 24),
            _buildVehicleSection(profile, isDark),
            const SizedBox(height: 24),
            _buildPendingTasks(profile, isDark),
            const SizedBox(height: 24),
            if (profile.isProfileComplete &&
                !profile.aprobado &&
                profile.estadoVerificacion != VerificationStatus.enRevision)
              _buildSubmitButton(provider, profile, isDark),
            const SizedBox(height: 24),
            if (profile.estadoVerificacion == VerificationStatus.enRevision)
              _buildInReviewMessage(isDark),
            const SizedBox(height: 24),
            _buildLogoutButton(isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionProgress(ConductorProfileModel profile, bool isDark) {
    final percentage = profile.completionPercentage;
    return _buildGlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Completitud del Perfil',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 12,
              backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.isProfileComplete
                ? '¡Perfil completo!'
                : 'Completa tu perfil para recibir viajes',
            style: TextStyle(
              color: profile.isProfileComplete
                  ? AppColors.success
                  : (isDark ? Colors.white70 : Colors.grey[600]),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatus(ConductorProfileModel profile, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    switch (profile.estadoVerificacion) {
      case VerificationStatus.pendiente:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_empty_rounded;
        statusMessage = 'Pendiente de verificación';
        break;
      case VerificationStatus.enRevision:
        statusColor = AppColors.info;
        statusIcon = Icons.search_rounded;
        statusMessage = 'En revisión por el equipo';
        break;
      case VerificationStatus.aprobado:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusMessage = '¡Perfil aprobado!';
        break;
      case VerificationStatus.rechazado:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        statusMessage = 'Documentos rechazados';
        break;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationStatusScreen(conductorId: widget.conductorId),
          ),
        );
      },
      child: _buildGlassCard(
        isDark: isDark,
        borderColor: statusColor.withOpacity(0.3),
        backgroundColor: statusColor.withOpacity(0.05),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.estadoVerificacion.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusMessage,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: statusColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseSection(ConductorProfileModel profile, bool isDark) {
    final license = profile.licencia;
    final hasLicense = license != null && license.isComplete;

    return _buildSection(
      title: 'Licencia de Conducción',
      icon: Icons.badge_rounded,
      isComplete: hasLicense,
      isDark: isDark,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LicenseRegistrationScreen(
              conductorId: widget.conductorId,
              existingLicense: license,
            ),
          ),
        );
        if (result == true && mounted) {
          Provider.of<ConductorProfileProvider>(
            context,
            listen: false,
          ).loadProfile(widget.conductorId);
        }
      },
      child: hasLicense
          ? Column(
              children: [
                _buildDetailRow('Número', license.numero, isDark),
                _buildDetailRow('Categoría', license.categoria.label, isDark),
                _buildDetailRow(
                  'Vencimiento',
                  '${license.fechaVencimiento.day}/${license.fechaVencimiento.month}/${license.fechaVencimiento.year}',
                  isDark,
                ),
                if (!license.isValid)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Licencia vencida - Renovar urgente',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No has registrado tu licencia',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[500], 
                  fontSize: 14
                ),
              ),
            ),
    );
  }

  Widget _buildVehicleSection(ConductorProfileModel profile, bool isDark) {
    final vehicle = profile.vehiculo;
    final hasVehicle = vehicle != null && vehicle.isBasicComplete;

    return _buildSection(
      title: 'Información del Vehículo',
      icon: Icons.directions_car_rounded,
      isComplete: hasVehicle,
      isDark: isDark,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleOnlyRegistrationScreen(
              conductorId: widget.conductorId,
              existingVehicle: vehicle,
            ),
          ),
        );
        if (result == true && mounted) {
          Provider.of<ConductorProfileProvider>(
            context,
            listen: false,
          ).loadProfile(widget.conductorId);
        }
      },
      child: hasVehicle
          ? Column(
              children: [
                _buildDetailRow('Placa', vehicle.placa.toUpperCase(), isDark),
                _buildDetailRow('Tipo', vehicle.tipo.label, isDark),
                _buildDetailRow('Marca', vehicle.marca ?? 'N/A', isDark),
                _buildDetailRow('Modelo', vehicle.modelo ?? 'N/A', isDark),
                _buildDetailRow('Año', vehicle.anio?.toString() ?? 'N/A', isDark),
                _buildDetailRow('Color', vehicle.color ?? 'N/A', isDark),
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No has registrado tu vehículo',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[500], 
                  fontSize: 14
                ),
              ),
            ),
    );
  }

  Widget _buildPendingTasks(ConductorProfileModel profile, bool isDark) {
    final tasks = profile.pendingTasks;
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tareas Pendientes',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...tasks.map((task) => _buildTaskItem(task, isDark)),
      ],
    );
  }

  Widget _buildTaskItem(String task, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, 
                fontSize: 15
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.primary,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isComplete,
    required VoidCallback onTap,
    required Widget child,
    required bool isDark,
  }) {
    return _buildGlassCard(
      isDark: isDark,
      borderColor: isComplete
          ? AppColors.success.withOpacity(0.3)
          : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isComplete ? AppColors.success : AppColors.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isComplete ? AppColors.success : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isComplete)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 24,
                    )
                  else
                    const Icon(
                      Icons.edit_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[600], 
              fontSize: 14
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
    ConductorProfileProvider provider,
    ConductorProfileModel profile,
    bool isDark,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: provider.isLoading
            ? null
            : () async {
                final result = await provider.submitForVerification(
                  widget.conductorId,
                );
                if (mounted) {
                  if (result) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '¡Perfil enviado para verificación exitosamente!',
                        ),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    await provider.loadProfile(widget.conductorId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.errorMessage ?? 'Error al enviar perfil',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
        child: provider.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Enviar para Verificación',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildInReviewMessage(bool isDark) {
    return _buildGlassCard(
      isDark: isDark,
      backgroundColor: AppColors.info.withOpacity(0.1),
      borderColor: AppColors.info.withOpacity(0.3),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: AppColors.info,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Verificación en Revisión',
            style: TextStyle(
              color: AppColors.info,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Tu perfil ha sido enviado y está siendo revisado por nuestro equipo. Te notificaremos cuando el proceso haya finalizado.',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.8) : Colors.grey[700],
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Tiempo estimado: 24-48 horas',
                    style: TextStyle(
                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== VISTA DE PERFIL APROBADO ==========

  Widget _buildApprovedProfileView(ConductorProfileModel profile, bool isDark) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildApprovedBadge(isDark),
            const SizedBox(height: 24),
            _buildApprovedPersonalInfoSection(profile, isDark),
            const SizedBox(height: 24),
            _buildApprovedLicenseSection(profile, isDark),
            const SizedBox(height: 24),
            _buildApprovedVehicleSection(profile, isDark),
            const SizedBox(height: 24),
            _buildApprovedDocumentsSection(profile, isDark),
            const SizedBox(height: 24),
            _buildApprovedSettingsSection(isDark),
            const SizedBox(height: 24),
            _buildApprovedAccountSection(isDark),
            const SizedBox(height: 24),
            _buildLogoutButton(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedBadge(bool isDark) {
    return _buildGlassCard(
      isDark: isDark,
      backgroundColor: AppColors.success.withOpacity(0.1),
      borderColor: AppColors.success.withOpacity(0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Conductor Verificado!',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu perfil ha sido aprobado y verificado',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600], 
                    fontSize: 14
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedPersonalInfoSection(ConductorProfileModel profile, bool isDark) {
    return _buildApprovedSection(
      title: 'Información Personal',
      icon: Icons.person_rounded,
      isDark: isDark,
      children: [
        _buildApprovedInfoTile(
          icon: Icons.badge_rounded,
          label: 'Estado',
          value: 'Conductor Activo',
          valueColor: AppColors.success,
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildApprovedInfoTile(
          icon: Icons.calendar_today_rounded,
          label: 'Verificado desde',
          value: _formatDate(profile.fechaUltimaVerificacion),
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildApprovedInfoTile(
          icon: Icons.security_rounded,
          label: 'Estado de Documentos',
          value: 'Todos verificados',
          valueColor: AppColors.success,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildApprovedLicenseSection(ConductorProfileModel profile, bool isDark) {
    final license = profile.licencia;
    final hasLicense = license != null && license.isComplete;

    return _buildApprovedSection(
      title: 'Licencia de Conducción',
      icon: Icons.credit_card_rounded,
      isDark: isDark,
      trailing: hasLicense
          ? IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              onPressed: () => _editLicense(license),
            )
          : null,
      children: hasLicense
          ? [
              _buildApprovedInfoTile(
                icon: Icons.numbers_rounded,
                label: 'Número',
                value: license.numero,
                isDark: isDark,
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
              _buildApprovedInfoTile(
                icon: Icons.category_rounded,
                label: 'Categoría',
                value: license.categoria.label,
                isDark: isDark,
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
              _buildApprovedInfoTile(
                icon: Icons.event_rounded,
                label: 'Fecha de Vencimiento',
                value:
                    '${license.fechaVencimiento.day}/${license.fechaVencimiento.month}/${license.fechaVencimiento.year}',
                valueColor: license.isValid
                    ? (license.isExpiringSoon ? AppColors.warning : (isDark ? Colors.white : Colors.black87))
                    : AppColors.error,
                isDark: isDark,
              ),
              if (license.isExpiringSoon || !license.isValid) ...[
                Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (license.isValid ? AppColors.warning : AppColors.error)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: license.isValid ? AppColors.warning : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          license.isValid
                              ? 'Tu licencia vence pronto. Considera renovarla.'
                              : 'Tu licencia está vencida. Renuévala urgentemente.',
                          style: TextStyle(
                            color: license.isValid ? AppColors.warning : AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]
          : [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No has registrado tu licencia',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500]),
                ),
              ),
            ],
    );
  }

  Widget _buildApprovedVehicleSection(ConductorProfileModel profile, bool isDark) {
    final vehicle = profile.vehiculo;
    final hasVehicle = vehicle != null && vehicle.isBasicComplete;

    return _buildApprovedSection(
      title: 'Información del Vehículo',
      icon: Icons.directions_car_rounded,
      isDark: isDark,
      trailing: hasVehicle
          ? IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              onPressed: () => _editVehicle(vehicle),
            )
          : null,
      children: hasVehicle
          ? [
              _buildApprovedInfoTile(
                icon: Icons.pin_rounded,
                label: 'Placa',
                value: vehicle.placa.toUpperCase(),
                isDark: isDark,
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
              _buildApprovedInfoTile(
                icon: Icons.car_rental_rounded,
                label: 'Tipo',
                value: vehicle.tipo.label,
                isDark: isDark,
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
              _buildApprovedInfoTile(
                icon: Icons.business_rounded,
                label: 'Marca',
                value: vehicle.marca ?? 'N/A',
                isDark: isDark,
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
              _buildApprovedInfoTile(
                icon: Icons.inventory_rounded,
                label: 'Modelo',
                value: vehicle.modelo ?? 'N/A',
                isDark: isDark,
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
              _buildApprovedInfoTile(
                icon: Icons.calendar_today_rounded,
                label: 'Año',
                value: vehicle.anio?.toString() ?? 'N/A',
                isDark: isDark,
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
              _buildApprovedInfoTile(
                icon: Icons.palette_rounded,
                label: 'Color',
                value: vehicle.color ?? 'N/A',
                isDark: isDark,
              ),
            ]
          : [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No has registrado tu vehículo',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500]),
                ),
              ),
            ],
    );
  }

  Widget _buildApprovedDocumentsSection(ConductorProfileModel profile, bool isDark) {
    return _buildApprovedSection(
      title: 'Documentos',
      icon: Icons.folder_rounded,
      isDark: isDark,
      children: [
        _buildDocumentItem(
          'Licencia de Conducción',
          Icons.badge_rounded,
          verified: profile.licencia != null,
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildDocumentItem(
          'SOAT',
          Icons.description_rounded,
          verified: profile.vehiculo?.fotoSoat != null,
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildDocumentItem(
          'Tarjeta de Propiedad',
          Icons.description_rounded,
          verified: profile.vehiculo?.fotoTarjetaPropiedad != null,
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildDocumentItem(
          'Tecnomecánica',
          Icons.build_rounded,
          verified: profile.vehiculo?.fotoTecnomecanica != null,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildDocumentItem(
    String title,
    IconData icon, {
    required bool verified,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (verified ? AppColors.success : AppColors.warning).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: verified ? AppColors.success : AppColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            verified ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: verified ? AppColors.success : AppColors.warning,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedSettingsSection(bool isDark) {
    return _buildApprovedSection(
      title: 'Configuración',
      icon: Icons.settings_rounded,
      isDark: isDark,
      children: [
        _buildSettingItem(
          'Notificaciones',
          Icons.notifications_rounded,
          onTap: () => _showComingSoon('Notificaciones'),
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildSettingItem(
          'Privacidad',
          Icons.privacy_tip_rounded,
          onTap: () => _showComingSoon('Privacidad'),
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildSettingItem(
          'Idioma',
          Icons.language_rounded,
          trailing: 'Español',
          onTap: () => _showComingSoon('Idioma'),
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildSettingItem(
          'Modo Oscuro',
          Icons.dark_mode_rounded,
          trailing: isDark ? 'Activado' : 'Desactivado',
          onTap: () => _showComingSoon('Modo Oscuro'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildApprovedAccountSection(bool isDark) {
    return _buildApprovedSection(
      title: 'Cuenta',
      icon: Icons.account_circle_rounded,
      isDark: isDark,
      children: [
        _buildSettingItem(
          'Ayuda y Soporte',
          Icons.help_rounded,
          onTap: () => _showComingSoon('Ayuda y Soporte'),
          isDark: isDark,
        ),
        Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
        _buildSettingItem(
          'Términos y Condiciones',
          Icons.article_rounded,
          onTap: () => _showComingSoon('Términos y Condiciones'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildApprovedSection({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
    required bool isDark,
  }) {
    return _buildGlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white54 : Colors.grey[500], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600], 
                fontSize: 14
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    String title,
    IconData icon, {
    String? trailing,
    Color? textColor,
    Color? iconColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon, 
              color: iconColor ?? (isDark ? Colors.white70 : Colors.grey[600]), 
              size: 24
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor ?? (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[500], 
                  fontSize: 14
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white54 : Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    required bool isDark,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: backgroundColor ?? (isDark ? AppColors.darkCard : Colors.white).withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ?? (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editLicense(license) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LicenseRegistrationScreen(
          conductorId: widget.conductorId,
          existingLicense: license,
        ),
      ),
    );
    if (result == true && mounted) {
      Provider.of<ConductorProfileProvider>(
        context,
        listen: false,
      ).loadProfile(widget.conductorId);
    }
  }

  void _editVehicle(vehicle) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleOnlyRegistrationScreen(
          conductorId: widget.conductorId,
          existingVehicle: vehicle,
        ),
      ),
    );
    if (result == true && mounted) {
      Provider.of<ConductorProfileProvider>(
        context,
        listen: false,
      ).loadProfile(widget.conductorId);
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature estará disponible próximamente'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => _buildLogoutDialog(isDark),
        );

        if (shouldLogout == true && mounted) {
          await UserService.clearSession();

          if (!mounted) return;

          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      },
      child: _buildGlassCard(
        isDark: isDark,
        backgroundColor: AppColors.error.withOpacity(0.1),
        borderColor: AppColors.error.withOpacity(0.3),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 12),
            Text(
              'Cerrar sesión',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutDialog(bool isDark) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkCard : Colors.white).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Cerrar sesión?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¿Estás seguro de que deseas cerrar sesión?',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.6) : Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildShimmerBox(height: 120, width: double.infinity, isDark: isDark),
            const SizedBox(height: 32),
            _buildShimmerBox(height: 90, width: double.infinity, isDark: isDark),
            const SizedBox(height: 24),
            _buildShimmerBox(height: 200, width: double.infinity, isDark: isDark),
            const SizedBox(height: 24),
            _buildShimmerBox(height: 250, width: double.infinity, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({required double height, double? width, required bool isDark}) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1A1A1A) : Colors.grey[300]!,
      highlightColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

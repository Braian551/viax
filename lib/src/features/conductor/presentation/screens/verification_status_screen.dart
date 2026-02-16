import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conductor_profile_model.dart';
import '../../providers/conductor_profile_provider.dart';
import '../../../../core/utils/colombian_plate_utils.dart';

class VerificationStatusScreen extends StatefulWidget {
  final int conductorId;

  const VerificationStatusScreen({
    super.key,
    required this.conductorId,
  });

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<ConductorProfileProvider>(context, listen: false);
    await provider.loadProfile(widget.conductorId);
    await provider.refreshVerificationStatus(widget.conductorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Consumer<ConductorProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildLoading();
          }

          final profile = provider.profile;
          if (profile == null) {
            return _buildError();
          }

          return _buildContent(profile);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Estado de VerificaciÃ³n',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFFFFF00),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar datos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFFF00),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Reintentar',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ConductorProfileModel profile) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFFFFF00),
      backgroundColor: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildStatusCard(profile),
              const SizedBox(height: 24),
              _buildProgressCard(profile),
              const SizedBox(height: 24),
              if (profile.hasPendingDocuments) ...[
                _buildPendingDocumentsCard(profile),
                const SizedBox(height: 24),
              ],
              if (profile.hasRejectedDocuments) ...[
                _buildRejectedDocumentsCard(profile),
                const SizedBox(height: 24),
              ],
              _buildLicenseCard(profile),
              const SizedBox(height: 16),
              _buildVehicleCard(profile),
              const SizedBox(height: 24),
              if (!profile.isProfileComplete)
                _buildCompleteProfileButton(profile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ConductorProfileModel profile) {
    final status = profile.estadoVerificacion;
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    switch (status) {
      case VerificationStatus.pendiente:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
        statusMessage = 'Tu perfil estÃ¡ pendiente de verificaciÃ³n';
        break;
      case VerificationStatus.enRevision:
        statusColor = Colors.blue;
        statusIcon = Icons.search_rounded;
        statusMessage = 'Tus documentos estÃ¡n siendo verificados';
        break;
      case VerificationStatus.aprobado:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusMessage = 'Â¡Tu perfil ha sido aprobado! Ya puedes recibir viajes';
        break;
      case VerificationStatus.rechazado:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusMessage = 'Tu perfil ha sido rechazado. Revisa los detalles abajo';
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              status.label,
              style: TextStyle(
                color: statusColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (profile.motivoRechazo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.motivoRechazo!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
    );
  }

  Widget _buildProgressCard(ConductorProfileModel profile) {
    final percentage = profile.completionPercentage;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progreso del Perfil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(percentage * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFFFFFF00),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00)),
                minHeight: 12,
              ),
            ),
            if (profile.pendingTasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Tareas Pendientes:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...profile.pendingTasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFF00),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDocumentsCard(ConductorProfileModel profile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Text(
                  'Documentos Pendientes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...profile.documentosPendientes.map((doc) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.upload_file_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      doc,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedDocumentsCard(ConductorProfileModel profile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'Documentos Rechazados',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...profile.documentosRechazados.map((doc) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      doc,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseCard(ConductorProfileModel profile) {
    final license = profile.licencia;
    final hasLicense = license != null && license.isComplete;
    
    return _buildInfoCard(
      title: 'Licencia de ConducciÃ³n',
      icon: Icons.badge_rounded,
      isComplete: hasLicense,
      details: hasLicense
          ? [
              'NÃºmero: ${license.numero}',
              'CategorÃ­a: ${license.categoria.label}',
              'Vence: ${_formatDate(license.fechaVencimiento)}',
              if (!license.isValid) 'âš ï¸ Licencia vencida',
              if (license.isExpiringSoon) 'âš ï¸ Vence pronto',
            ]
          : ['Sin informaciÃ³n de licencia'],
    );
  }

  Widget _buildVehicleCard(ConductorProfileModel profile) {
    final vehicle = profile.vehiculo;
    final hasVehicle = vehicle != null && vehicle.isBasicComplete;
    
    return _buildInfoCard(
      title: 'VehÃ­culo',
      icon: Icons.directions_car_rounded,
      isComplete: hasVehicle,
      details: hasVehicle
          ? [
              vehicle.tipo.label,
              '${vehicle.marca} ${vehicle.modelo}',
              'Placa: ${ColombianPlateUtils.formatForDisplay(vehicle.placa)}',
              'Color: ${vehicle.color}',
            ]
          : ['Sin informaciÃ³n de vehÃ­culo'],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required bool isComplete,
    required List<String> details,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isComplete
              ? const Color(0xFF11998e).withValues(alpha: 0.15)
              : const Color(0xFF1A1A1A).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isComplete
                ? const Color(0xFF11998e).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFF11998e).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isComplete ? const Color(0xFF11998e) : Colors.white54,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  isComplete ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isComplete ? Colors.green : Colors.red,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...details.map((detail) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                detail,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteProfileButton(ConductorProfileModel profile) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/conductor/profile/edit',
            arguments: widget.conductorId,
          ).then((_) => _loadData());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFF00),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Completar Perfil',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}


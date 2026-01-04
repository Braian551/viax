import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/features/company/data/datasources/company_remote_datasource.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

// Reutilizamos los widgets del admin
import 'package:viax/src/features/admin/presentation/widgets/conductor_card.dart';
import 'package:viax/src/features/admin/presentation/widgets/documents_loading_shimmer.dart';
import 'package:viax/src/features/admin/presentation/screens/conductor_details_sheet.dart';
import 'package:viax/src/features/admin/presentation/screens/document_viewer_screen.dart';

/// Pantalla para gestionar documentos de conductores que aplicaron a la empresa
class CompanyConductoresDocumentosScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final dynamic empresaId;

  const CompanyConductoresDocumentosScreen({
    super.key,
    required this.user,
    required this.empresaId,
  });

  @override
  State<CompanyConductoresDocumentosScreen> createState() =>
      _CompanyConductoresDocumentosScreenState();
}

class _CompanyConductoresDocumentosScreenState
    extends State<CompanyConductoresDocumentosScreen> {
  late final CompanyRemoteDataSource _dataSource;

  bool _isLoading = true;
  List<Map<String, dynamic>> _conductores = [];
  Map<String, dynamic>? _estadisticas;
  Map<String, dynamic>? _solicitudesPendientes;
  String _filtroEstado = 'todos';

  final Map<String, String> _estadosLabels = {
    'todos': 'Todos',
    'pendiente': 'Pendientes',
    'en_revision': 'En Revisión',
    'aprobado': 'Aprobados',
    'rechazado': 'Rechazados',
  };

  @override
  void initState() {
    super.initState();
    _dataSource = CompanyRemoteDataSourceImpl(client: http.Client());
    _loadDocumentos();
  }

  Future<void> _loadDocumentos() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dataSource.getConductoresDocumentos(
        empresaId: widget.empresaId,
        estadoVerificacion: _filtroEstado == 'todos' ? null : _filtroEstado,
      );

      if (!mounted) return;

      setState(() {
        _conductores = List<Map<String, dynamic>>.from(
          data['conductores'] ?? [],
        );
        _estadisticas = data['estadisticas'];
        _solicitudesPendientes = data['solicitudes_pendientes'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, message: 'Error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(
                context,
              ).colorScheme.surfaceContainer.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Theme.of(context).cardColor,
          onRefresh: _loadDocumentos,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (_isLoading && _conductores.isEmpty)
                const SliverToBoxAdapter(child: DocumentsLoadingShimmer())
              else ...[
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.top + 70,
                  ),
                ),
                // Mostrar solicitudes pendientes de vinculación
                if (_solicitudesPendientes != null &&
                    (_solicitudesPendientes!['total'] ?? 0) > 0)
                  SliverToBoxAdapter(child: _buildSolicitudesPendientes()),
                if (_estadisticas != null)
                  SliverToBoxAdapter(child: _buildEstadisticas()),
                SliverToBoxAdapter(child: _buildFilterSection()),
                _buildContent(),
                const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.85),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Theme.of(context).colorScheme.onSurface,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Documentos de Conductores',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: _loadDocumentos,
          tooltip: 'Actualizar',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSolicitudesPendientes() {
    final total = _solicitudesPendientes!['total'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withValues(alpha: 0.15),
              AppColors.warning.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total Solicitudes de Vinculación',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Conductores quieren unirse a tu empresa',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: Navegar a pantalla de solicitudes de vinculación
                CustomSnackbar.showInfo(
                  context,
                  message: 'Próximamente: Gestión de solicitudes',
                );
              },
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumen de Conductores',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pendientes',
                  _estadisticas!['pendientes_verificacion']?.toString() ?? '0',
                  Icons.pending_actions_rounded,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Aprobados',
                  _estadisticas!['aprobados']?.toString() ?? '0',
                  Icons.verified_user_rounded,
                  AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Vencidos',
                  _estadisticas!['con_documentos_vencidos']?.toString() ?? '0',
                  Icons.warning_amber_rounded,
                  AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _estadisticas!['total_conductores']?.toString() ?? '0',
                  Icons.people_outline_rounded,
                  AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Filtrar por estado',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _estadosLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = _estadosLabels.entries.elementAt(index);
              final isSelected = _filtroEstado == entry.key;

              return GestureDetector(
                onTap: () {
                  setState(() => _filtroEstado = entry.key);
                  _loadDocumentos();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildContent() {
    if (_conductores.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final conductor = _conductores[index];
          return ConductorCard(
            conductor: conductor,
            onTap: () => _showConductorDetails(conductor),
            onAprobar: () => _aprobarConductor(conductor),
            onRechazar: () => _rechazarConductor(conductor),
          );
        }, childCount: _conductores.length),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron conductores',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no hay conductores vinculados a tu empresa',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _aprobarConductor(Map<String, dynamic> conductor) async {
    final confirm = await _showConfirmationDialog(
      title: 'Aprobar Conductor',
      message:
          '¿Deseas aprobar a ${conductor['nombre_completo']}?\n\nSus documentos han sido verificados y podrá realizar viajes.',
    );

    if (confirm == true) {
      // Safely parse IDs
      final conductorIdParsed = int.tryParse(conductor['usuario_id']?.toString() ?? '');
      final procesadoPorParsed = int.tryParse(widget.user['id']?.toString() ?? '');
      
      if (conductorIdParsed == null || procesadoPorParsed == null) {
        CustomSnackbar.showError(context, message: 'Error: ID inválido');
        return;
      }

      // Determine correct action based on conductor status
      final bool esSolicitud = conductor['es_solicitud_pendiente'] == true;
      final String accion = esSolicitud ? 'aprobar_solicitud' : 'aprobar_documentos';

      _showLoadingDialog('Aprobando conductor...');

      try {
        final success = await _dataSource.procesarSolicitudConductor(
          empresaId: widget.empresaId,
          conductorId: conductorIdParsed,
          accion: accion,
          procesadoPor: procesadoPorParsed,
        );

        if (Navigator.canPop(context)) Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;

        if (success) {
          CustomSnackbar.showSuccess(
            context,
            message: 'Conductor aprobado exitosamente',
          );
          _loadDocumentos();
        } else {
          CustomSnackbar.showError(
            context,
            message: 'Error al aprobar conductor',
          );
        }
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          CustomSnackbar.showError(context, message: 'Error: $e');
        }
      }
    }
  }

  Future<void> _rechazarConductor(Map<String, dynamic> conductor) async {
    final motivo = await _showRejectionDialog(
      conductor['nombre_completo'] ?? 'Conductor',
    );

    if (motivo != null && motivo.isNotEmpty) {
      // Safely parse IDs
      final conductorIdParsed = int.tryParse(conductor['usuario_id']?.toString() ?? '');
      final procesadoPorParsed = int.tryParse(widget.user['id']?.toString() ?? '');
      
      if (conductorIdParsed == null || procesadoPorParsed == null) {
        CustomSnackbar.showError(context, message: 'Error: ID inválido');
        return;
      }

      // Determine correct action based on conductor status
      final bool esSolicitud = conductor['es_solicitud_pendiente'] == true;
      final String accion = esSolicitud ? 'rechazar_solicitud' : 'rechazar_documentos';

      _showLoadingDialog('Rechazando conductor...');

      try {
        final success = await _dataSource.procesarSolicitudConductor(
          empresaId: widget.empresaId,
          conductorId: conductorIdParsed,
          accion: accion,
          procesadoPor: procesadoPorParsed,
          razon: motivo,
        );

        if (Navigator.canPop(context)) Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;

        if (success) {
          CustomSnackbar.showSuccess(context, message: 'Conductor rechazado');
          _loadDocumentos();
        } else {
          CustomSnackbar.showError(
            context,
            message: 'Error al rechazar conductor',
          );
        }
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          CustomSnackbar.showError(context, message: 'Error: $e');
        }
      }
    }
  }

  Future<String?> _showRejectionDialog(String conductorName) async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rechazar Conductor',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conductor: $conductorName',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Motivo del rechazo...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  void _showConductorDetails(Map<String, dynamic> conductor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConductorDetailsSheet(
        conductor: conductor,
        onAprobar: () {
          Navigator.pop(context);
          _aprobarConductor(conductor);
        },
        onRechazar: () {
          Navigator.pop(context);
          _rechazarConductor(conductor);
        },
        onShowHistory: (conductorId) {
          // Por ahora mostramos un mensaje
          CustomSnackbar.showInfo(context, message: 'Historial próximamente');
        },
        onViewDocument: _viewDocument,
      ),
    );
  }

  void _viewDocument(
    String? documentUrl,
    String documentName, {
    String? tipoArchivo,
  }) {
    if (documentUrl == null || documentUrl.isEmpty) {
      CustomSnackbar.showError(context, message: 'Documento no disponible');
      return;
    }

    String fullUrl;
    if (documentUrl.startsWith('http')) {
      fullUrl = documentUrl;
    } else {
      fullUrl = '${AppConfig.baseUrl}/r2_proxy.php?key=$documentUrl';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          documentUrl: fullUrl,
          documentName: documentName,
          tipoArchivo: tipoArchivo,
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }
}

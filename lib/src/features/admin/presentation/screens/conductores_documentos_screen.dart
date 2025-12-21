import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'document_viewer_screen.dart';
import 'conductor_details_sheet.dart';
import 'conductor_actions.dart';

class ConductoresDocumentosScreen extends StatefulWidget {
  final int adminId;
  final Map<String, dynamic> adminUser;

  const ConductoresDocumentosScreen({
    super.key,
    required this.adminId,
    required this.adminUser,
  });

  @override
  State<ConductoresDocumentosScreen> createState() => _ConductoresDocumentosScreenState();
}

class _ConductoresDocumentosScreenState extends State<ConductoresDocumentosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conductores = [];
  Map<String, dynamic>? _estadisticas;
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
    print('ConductoresDocumentosScreen: adminId recibido: ${widget.adminId}');
    print('ConductoresDocumentosScreen: adminUser completo: ${widget.adminUser}');
    _loadDocumentos();
  }

  Future<void> _loadDocumentos() async {
    setState(() => _isLoading = true);

    try {
      final response = await AdminService.getConductoresDocumentos(
        adminId: widget.adminId,
        estadoVerificacion: _filtroEstado == 'todos' ? null : _filtroEstado,
      );

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _conductores = List<Map<String, dynamic>>.from(response['data']['conductores'] ?? []);
          _estadisticas = response['data']['estadisticas'];
          _isLoading = false;
        });
      } else {
        _showError(response['message'] ?? 'Error al cargar documentos');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Error al cargar documentos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    CustomSnackbar.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildShimmerLoading() : _buildContent(),
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
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
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
      ],
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: _loadDocumentos,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildEstadisticas()),
          SliverToBoxAdapter(child: _buildFiltros()),
          _buildConductoresList(),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    if (_estadisticas == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen General',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                'Total',
                _estadisticas!['total_conductores'].toString(),
                Icons.people_rounded,
                const Color(0xFF667eea),
              ),
              _buildStatCard(
                'Pendientes',
                _estadisticas!['pendientes_verificacion'].toString(),
                Icons.pending_rounded,
                const Color(0xFFffa726),
              ),
              _buildStatCard(
                'Aprobados',
                _estadisticas!['aprobados'].toString(),
                Icons.check_circle_rounded,
                const Color(0xFF11998e),
              ),
              _buildStatCard(
                'Docs. Vencidos',
                _estadisticas!['con_documentos_vencidos'].toString(),
                Icons.warning_rounded,
                const Color(0xFFf5576c),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrar por estado',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _estadosLabels.length,
              itemBuilder: (context, index) {
                final entry = _estadosLabels.entries.elementAt(index);
                final isSelected = _filtroEstado == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _filtroEstado = entry.key);
                      _loadDocumentos();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color.fromRGBO(33, 150, 243, 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value,
                            style: TextStyle(
                              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildConductoresList() {
    if (_conductores.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay conductores en esta categoría',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final conductor = _conductores[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildConductorCard(conductor),
            );
          },
          childCount: _conductores.length,
        ),
      ),
    );
  }

  Widget _buildConductorCard(Map<String, dynamic> conductor) {
    final estadoVerificacion = conductor['estado_verificacion'] ?? 'pendiente';
    final Color estadoColor = _getEstadoColor(estadoVerificacion);
    final hasVencidos = conductor['tiene_documentos_vencidos'] == true;
    
    return GestureDetector(
      onTap: () => _showConductorDetails(conductor),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: estadoColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.drive_eta_rounded,
                        color: estadoColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conductor['nombre_completo'] ?? 'Sin nombre',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            conductor['email'] ?? 'Sin email',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildEstadoBadge(estadoVerificacion, estadoColor),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        Icons.badge_rounded,
                        'Licencia',
                        conductor['licencia_conduccion'] ?? 'N/A',
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        Icons.local_taxi_rounded,
                        'Placa',
                        conductor['vehiculo_placa'] ?? 'N/A',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        Icons.star_rounded,
                        'Calificación',
                        '${conductor['calificacion_promedio'] ?? 0.0} (${conductor['total_calificaciones'] ?? 0})',
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        Icons.directions_car_rounded,
                        'Viajes',
                        '${conductor['total_viajes'] ?? 0}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (conductor['porcentaje_completitud'] ?? 0) / 100,
                  backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(estadoColor),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Documentos: ${conductor['documentos_completos']}/${conductor['total_documentos_requeridos']}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    if (hasVencidos)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf5576c).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_rounded, color: Color(0xFFf5576c), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Docs. Vencidos',
                              style: TextStyle(
                                color: Color(0xFFf5576c),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

  Widget _buildEstadoBadge(String estado, Color color) {
    final Map<String, String> estadosTexto = {
      'pendiente': 'Pendiente',
      'en_revision': 'En Revisión',
      'aprobado': 'Aprobado',
      'rechazado': 'Rechazado',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Text(
        estadosTexto[estado] ?? estado,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'aprobado':
        return const Color(0xFF11998e);
      case 'rechazado':
        return const Color(0xFFf5576c);
      case 'en_revision':
        return const Color(0xFF667eea);
      case 'pendiente':
      default:
        return const Color(0xFFffa726);
    }
  }

  void _showConductorDetails(Map<String, dynamic> conductor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConductorDetailsSheet(
        conductor: conductor,
        onAprobar: () => aprobarConductor(
          context: context,
          adminId: widget.adminId,
          conductor: conductor,
          onSuccess: _loadDocumentos,
        ),
        onRechazar: () => rechazarConductor(
          context: context,
          adminId: widget.adminId,
          conductor: conductor,
          onSuccess: _loadDocumentos,
        ),
        onShowHistory: (conductorId) => showDocumentHistory(
          context: context,
          adminId: widget.adminId,
          conductorId: conductorId,
        ),
        onViewDocument: _viewDocument,
      ),
    );
  }

  /// Muestra un documento en pantalla completa
  void _viewDocument(String? documentUrl, String documentName) {
    if (documentUrl == null || documentUrl.isEmpty) {
      _showError('Documento no disponible');
      return;
    }

    // Construir URL completa si es relativa
    final String fullUrl = documentUrl.startsWith('http') 
        ? documentUrl 
        : '${AppConfig.baseUrl}/$documentUrl';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          documentUrl: fullUrl,
          documentName: documentName,
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFF1A1A1A),
              highlightColor: const Color(0xFF2A2A2A),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/features/admin/presentation/widgets/conductor_card.dart';
import 'conductor_details_sheet.dart';
import 'document_viewer_screen.dart';
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
    _loadDocumentos();
  }

  Future<void> _loadDocumentos() async {
    setState(() => _isLoading = true);

    try {
      final response = await AdminService.getConductoresDocumentos(
        adminId: widget.adminId,
        estadoVerificacion: _filtroEstado == 'todos' ? null : _filtroEstado,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _conductores = List<Map<String, dynamic>>.from(response['data']['conductores'] ?? []);
          _estadisticas = response['data']['estadisticas'];
          _isLoading = false;
        });
      } else {
        CustomSnackbar.showError(context, message: response['message'] ?? 'Error al cargar documentos');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, message: 'Error de conexión: $e');
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
              Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
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
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 70)),
              if (_estadisticas != null)
                SliverToBoxAdapter(child: _buildEstadisticas()),
              SliverToBoxAdapter(child: _buildFilterSection()),
              _buildContent(),
              const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
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

  Widget _buildEstadisticas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Resumen General',
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
                  _estadisticas!['pendientes_verificacion'].toString(),
                  Icons.pending_actions_rounded,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Aprobados',
                  _estadisticas!['aprobados'].toString(),
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
                  _estadisticas!['con_documentos_vencidos'].toString(),
                  Icons.warning_amber_rounded,
                  AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _estadisticas!['total_conductores'].toString(),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
              final color = isSelected ? AppColors.primary : Theme.of(context).dividerColor;
              
              return GestureDetector(
                onTap: () {
                  setState(() => _filtroEstado = entry.key);
                  _loadDocumentos();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primary 
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: isSelected 
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
    if (_isLoading && _conductores.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildLoadingState(),
      );
    }

    if (_conductores.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final conductor = _conductores[index];
            return ConductorCard(
              conductor: conductor,
              onTap: () => _showConductorDetails(conductor),
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
            );
          },
          childCount: _conductores.length,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Cargando conductores...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
            'Intenta cambiar los filtros de búsqueda',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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

  void _viewDocument(String? documentUrl, String documentName) {
    if (documentUrl == null || documentUrl.isEmpty) {
      CustomSnackbar.showError(context, message: 'Documento no disponible');
      return;
    }

    String fullUrl;
    if (documentUrl.startsWith('http')) {
      fullUrl = documentUrl;
    } else {
      // Si no empieza con http, asumimos que es una key de R2 y usamos el proxy
      // Esto arregla la visualización de imágenes de Cloudflare
      fullUrl = '${AppConfig.baseUrl}/r2_proxy.php?key=$documentUrl';
    }

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
}

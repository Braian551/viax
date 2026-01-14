import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/documents/documents_widgets.dart';
import '../../providers/conductor_profile_provider.dart';
import '../../models/conductor_profile_model.dart';
import './documents_management_screen.dart';
import './vehicle_only_registration_screen.dart';

/// Pantalla de Documentos del Conductor
/// 
/// Muestra el estado de todos los documentos requeridos
/// para operar como conductor.
class ConductorDocumentsScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;

  const ConductorDocumentsScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
  });

  @override
  State<ConductorDocumentsScreen> createState() => _ConductorDocumentsScreenState();
}

class _ConductorDocumentsScreenState extends State<ConductorDocumentsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDocuments();
    });
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    
    final conductorId = widget.conductorId;
    if (conductorId > 0) {
      context.read<ConductorProfileProvider>().loadProfile(conductorId);
    }
  }

  List<DocumentItem> _buildDocumentsList(ConductorProfileModel profile) {
    final now = DateTime.now();
    final List<DocumentItem> documents = [];
    
    // 1. Licencia de Conducir
    final license = profile.licencia;
    if (license != null) {
      final isExpired = license.fechaVencimiento.isBefore(now);
      final isExpiringSoon = license.fechaVencimiento.difference(now).inDays <= 30 && !isExpired;
      
      documents.add(DocumentItem(
        id: 'licencia',
        title: 'Licencia de Conducir',
        description: 'Categoría ${license.categoria.label}',
        icon: Icons.badge_rounded,
        status: isExpired 
            ? DocumentStatus.expired 
            : (isExpiringSoon ? DocumentStatus.pending : DocumentStatus.approved),
        expirationDate: '${license.fechaVencimiento.day}/${license.fechaVencimiento.month}/${license.fechaVencimiento.year}',
      ));
    } else {
      documents.add(DocumentItem(
        id: 'licencia',
        title: 'Licencia de Conducir',
        description: 'No registrada',
        icon: Icons.badge_rounded,
        status: DocumentStatus.missing,
      ));
    }
    
    // 2. SOAT
    final vehicle = profile.vehiculo;
    if (vehicle != null && vehicle.soatNumero != null && vehicle.soatNumero!.isNotEmpty) {
      final isExpired = vehicle.soatVencimiento != null && vehicle.soatVencimiento!.isBefore(now);
      final isExpiringSoon = vehicle.soatVencimiento != null && 
          vehicle.soatVencimiento!.difference(now).inDays <= 30 &&
          !isExpired;
      
      documents.add(DocumentItem(
        id: 'soat',
        title: 'SOAT',
        description: 'Póliza: ${vehicle.soatNumero}',
        icon: Icons.health_and_safety_rounded,
        status: isExpired 
            ? DocumentStatus.expired 
            : (isExpiringSoon ? DocumentStatus.pending : DocumentStatus.approved),
        expirationDate: vehicle.soatVencimiento != null 
            ? '${vehicle.soatVencimiento!.day}/${vehicle.soatVencimiento!.month}/${vehicle.soatVencimiento!.year}'
            : null,
      ));
    } else {
      documents.add(DocumentItem(
        id: 'soat',
        title: 'SOAT',
        description: 'No registrado',
        icon: Icons.health_and_safety_rounded,
        status: DocumentStatus.missing,
      ));
    }
    
    // 3. Tecnomecánica  
    if (vehicle != null && vehicle.tecnomecanicaNumero != null && vehicle.tecnomecanicaNumero!.isNotEmpty) {
      final isExpired = vehicle.tecnomecanicaVencimiento != null && vehicle.tecnomecanicaVencimiento!.isBefore(now);
      final isExpiringSoon = vehicle.tecnomecanicaVencimiento != null && 
          vehicle.tecnomecanicaVencimiento!.difference(now).inDays <= 30 &&
          !isExpired;
      
      documents.add(DocumentItem(
        id: 'tecnomecanica',
        title: 'Tecnomecánica',
        description: 'Certificado: ${vehicle.tecnomecanicaNumero}',
        icon: Icons.build_circle_rounded,
        status: isExpired 
            ? DocumentStatus.expired 
            : (isExpiringSoon ? DocumentStatus.pending : DocumentStatus.approved),
        expirationDate: vehicle.tecnomecanicaVencimiento != null 
            ? '${vehicle.tecnomecanicaVencimiento!.day}/${vehicle.tecnomecanicaVencimiento!.month}/${vehicle.tecnomecanicaVencimiento!.year}'
            : null,
      ));
    } else {
      documents.add(DocumentItem(
        id: 'tecnomecanica',
        title: 'Tecnomecánica',
        description: 'No registrada',
        icon: Icons.build_circle_rounded,
        status: DocumentStatus.missing,
      ));
    }
    
    // 4. Tarjeta de Propiedad (no tiene vencimiento)
    if (vehicle != null && vehicle.tarjetaPropiedadNumero != null && vehicle.tarjetaPropiedadNumero!.isNotEmpty) {
      documents.add(DocumentItem(
        id: 'tarjeta_propiedad',
        title: 'Tarjeta de Propiedad',
        description: 'Número: ${vehicle.tarjetaPropiedadNumero}',
        icon: Icons.card_membership_rounded,
        status: DocumentStatus.approved,
      ));
    } else {
      documents.add(DocumentItem(
        id: 'tarjeta_propiedad',
        title: 'Tarjeta de Propiedad',
        description: 'No registrada',
        icon: Icons.card_membership_rounded,
        status: DocumentStatus.missing,
      ));
    }
    
    return documents;
  }

  void _handleDocumentTap(DocumentItem document) {
    // Ver detalles del documento
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDocumentDetailSheet(document),
    );
  }

  void _handleUploadDocument(DocumentItem document) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Subir ${document.title}'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: widget.conductorUser != null
          ? ConductorDrawer(conductorUser: widget.conductorUser!)
          : null,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: _buildContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      leading: widget.conductorUser != null
          ? IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            )
          : IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _headerController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Documentos',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gestiona tu documentación',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return Consumer<ConductorProfileProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const DocumentsShimmer();
        }

        if (provider.errorMessage != null) {
          return DocumentsEmptyState(
            errorMessage: provider.errorMessage,
            onRetry: _loadDocuments,
          );
        }

        final profile = provider.profile;
        if (profile == null) {
          return const DocumentsEmptyState();
        }

        final documents = _buildDocumentsList(profile);

        final expiredDocs = documents.where((d) => d.status == DocumentStatus.expired || d.status == DocumentStatus.missing).toList();
        final pendingDocs = documents.where((d) => d.status == DocumentStatus.pending).toList();

        return RefreshIndicator(
          onRefresh: _loadDocuments,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expiredDocs.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Documentos Vencidos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tienes ${expiredDocs.length} documento(s) vencido(s). Por favor actualízalos para evitar bloqueos.',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else if (pendingDocs.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.access_time_rounded, color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Documentos por Vencer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tienes ${pendingDocs.length} documento(s) próximo(s) a vencer. Actualízalos pronto.',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mis Documentos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (profile.vehiculo != null)
                      TextButton.icon(
                        onPressed: () => _navigateToDocumentsManagement(profile),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Editar'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(documents.length, (index) {
                  final doc = documents[index];
                  return DocumentCard(
                    document: doc,
                    animationIndex: index,
                    onTap: () => _handleDocumentTap(doc),
                    onUpload: () => _handleUploadDocument(doc),
                  );
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToDocumentsManagement(ConductorProfileModel profile) {
    if (profile.vehiculo != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentsManagementScreen(
            conductorId: widget.conductorId,
            vehicle: profile.vehiculo!,
          ),
        ),
      ).then((changed) {
        if (changed == true) {
          _loadDocuments();
        }
      });
    }
  }

  void _navigateToLicenseManagement(ConductorProfileModel profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleOnlyRegistrationScreen(
          conductorId: widget.conductorId,
          conductorUser: widget.conductorUser,
          existingLicense: profile.licencia,
          initialStep: 1, // Step for License
        ),
      ),
    ).then((_) {
      _loadDocuments();
    });
  }

  Widget _buildDocumentDetailSheet(DocumentItem document) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    document.icon,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  document.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  document.description,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (document.expirationDate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Vence: ${document.expirationDate}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cerrar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          final profile = context.read<ConductorProfileProvider>().profile;
                          if (profile == null) return;
                          
                          if (document.id == 'licencia') {
                            _navigateToLicenseManagement(profile);
                          } else {
                            _navigateToDocumentsManagement(profile);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Actualizar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

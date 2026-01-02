import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/documents/documents_widgets.dart';

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

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  List<DocumentItem> _documents = [];

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

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (!mounted) return;

      // Documentos de ejemplo - En producción obtener del backend
      setState(() {
        _documents = [
          DocumentItem(
            id: 'license',
            title: 'Licencia de Conducir',
            description: 'Licencia tipo B vigente',
            icon: Icons.badge_rounded,
            status: DocumentStatus.approved,
            expirationDate: '15/06/2026',
          ),
          DocumentItem(
            id: 'id_card',
            title: 'Identificación Oficial',
            description: 'INE o Pasaporte vigente',
            icon: Icons.credit_card_rounded,
            status: DocumentStatus.approved,
          ),
          DocumentItem(
            id: 'vehicle_card',
            title: 'Tarjeta de Circulación',
            description: 'Documento del vehículo',
            icon: Icons.description_rounded,
            status: DocumentStatus.approved,
            expirationDate: '30/12/2025',
          ),
          // Insurance removed
          DocumentItem(
            id: 'criminal_record',
            title: 'Antecedentes Penales',
            description: 'Carta de no antecedentes',
            icon: Icons.gavel_rounded,
            status: DocumentStatus.approved,
          ),
          DocumentItem(
            id: 'proof_address',
            title: 'Comprobante de Domicilio',
            description: 'No mayor a 3 meses',
            icon: Icons.home_rounded,
            status: DocumentStatus.expired,
            expirationDate: 'Vencido',
          ),
          DocumentItem(
            id: 'photo',
            title: 'Fotografía de Perfil',
            description: 'Foto reciente visible',
            icon: Icons.person_rounded,
            status: DocumentStatus.approved,
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Error al cargar los documentos';
        _isLoading = false;
      });
    }
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
    if (_isLoading) {
      return const DocumentsShimmer();
    }

    if (_hasError) {
      return DocumentsEmptyState(
        errorMessage: _errorMessage,
        onRetry: _loadDocuments,
      );
    }

    if (_documents.isEmpty) {
      return const DocumentsEmptyState();
    }

    final approved = _documents.where((d) => d.status == DocumentStatus.approved).length;
    final pending = _documents.where((d) => d.status == DocumentStatus.pending).length;
    final rejected = _documents.where((d) => 
        d.status == DocumentStatus.rejected || 
        d.status == DocumentStatus.expired ||
        d.status == DocumentStatus.missing
    ).length;

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DocumentsSummaryCard(
              totalDocuments: _documents.length,
              approvedDocuments: approved,
              pendingDocuments: pending,
              rejectedDocuments: rejected,
            ),
            const SizedBox(height: 24),
            Text(
              'Mis Documentos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_documents.length, (index) {
              final doc = _documents[index];
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
                          _handleUploadDocument(document);
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

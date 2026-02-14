import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';
import '../../../domain/models/company_vehicle_models.dart';
import '../../../data/services/company_vehicle_service.dart';
import '../../../../../global/services/auth/user_service.dart';

/// Sheet para mostrar información detallada de una empresa
/// Rediseño consistente con DraggableDriverPanel / TripBottomPanel
class CompanyDetailsSheet extends StatefulWidget {
  const CompanyDetailsSheet({
    super.key,
    required this.empresaId,
    required this.isDark,
  });

  final int empresaId;
  final bool isDark;

  @override
  State<CompanyDetailsSheet> createState() => _CompanyDetailsSheetState();
}

class _CompanyDetailsSheetState extends State<CompanyDetailsSheet>
    with SingleTickerProviderStateMixin {
  CompanyDetails? _details;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadDetails();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      final details =
          await CompanyVehicleService.getCompanyDetails(widget.empresaId);
      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
          if (details == null) {
            _error = 'No se pudo cargar la información';
          }
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error de conexión';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.8, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.98)
                : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _error != null
                        ? _buildError()
                        : _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Handle ──────────────────────────────────────────────────────────

  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        width: double.infinity,
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading ─────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando información...',
            style: TextStyle(
              color: widget.isDark ? Colors.white54 : Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ───────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: widget.isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadDetails();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ─────────────────────────────────────────────────────────

  Widget _buildContent(ScrollController scrollController) {
    final details = _details!;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
      child: ListView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          // ── Header: Avatar + Name ──
          _buildHeader(details),

          const SizedBox(height: 20),

          // ── Divider ──
          _buildGradientDivider(),

          const SizedBox(height: 20),

          // ── Stats Row ──
          _buildStatsRow(details),

          const SizedBox(height: 24),

          // ── Flota ──
          if (details.tiposVehiculo.isNotEmpty) ...[
            _buildSectionTitle('Flota disponible'),
            const SizedBox(height: 12),
            _buildFleetChips(details),
            const SizedBox(height: 24),
          ],

          // ── Acerca de ──
          if (details.descripcion != null &&
              details.descripcion!.isNotEmpty) ...[
            _buildSectionTitle('Acerca de'),
            const SizedBox(height: 10),
            _buildAboutCard(details),
            const SizedBox(height: 24),
          ],

          // ── Contacto ──
          if (details.telefono != null ||
              details.email != null ||
              details.municipio != null) ...[
            _buildSectionTitle('Contacto'),
            const SizedBox(height: 12),
            _buildContactSection(details),
          ],
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader(CompanyDetails details) {
    return Row(
      children: [
        // Logo con borde gradiente (estilo avatar driver)
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.8),
                AppColors.primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: details.logoUrl != null
                  ? Image.network(
                      UserService.getR2ImageUrl(details.logoUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _a, _b) => _buildLogoPlaceholder(details.nombre),
                    )
                  : _buildLogoPlaceholder(details.nombre),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre + verificado
              Row(
                children: [
                  Flexible(
                    child: Text(
                      details.nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: widget.isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (details.verificada) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.verified_rounded,
                        color: AppColors.primary, size: 22),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Rating badge (estilo accent como DraggableDriverPanel)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.accent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      details.calificacionPromedio?.toStringAsFixed(1) ??
                          'N/A',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    if (details.totalCalificaciones > 0) ...[
                      Text(
                        ' · ${details.totalCalificaciones} reseñas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPlaceholder(String nombre) {
    return Container(
      color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
      child: Center(
        child: Text(
          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Gradient Divider ────────────────────────────────────────────────

  Widget _buildGradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            widget.isDark ? Colors.white24 : Colors.grey[300]!,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ── Stats ───────────────────────────────────────────────────────────

  Widget _buildStatsRow(CompanyDetails details) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.route_rounded,
            value: '${details.viajesCompletados}',
            label: 'Viajes',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_alt_rounded,
            value: '${details.totalConductores}',
            label: 'Conductores',
            color: AppColors.blue600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.star_rounded,
            value: details.calificacionPromedio?.toStringAsFixed(1) ?? '-',
            label: 'Rating',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: widget.isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white54 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Title ───────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ── Fleet Chips ─────────────────────────────────────────────────────

  Widget _buildFleetChips(CompanyDetails details) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: details.tiposVehiculo.map((tipo) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getVehicleIcon(tipo.nombre),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                tipo.nombre,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── About Card ──────────────────────────────────────────────────────

  Widget _buildAboutCard(CompanyDetails details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details.descripcion!,
            style: TextStyle(
              color: widget.isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (details.anioFundacion != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: widget.isDark ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  'Fundada en ${details.anioFundacion}',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white38 : Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Contact Section ─────────────────────────────────────────────────

  Widget _buildContactSection(CompanyDetails details) {
    return Column(
      children: [
        if (details.municipio != null)
          _buildContactRow(
            icon: Icons.location_on_rounded,
            label: 'Ubicación',
            value:
                '${details.municipio}${details.departamento != null ? ", ${details.departamento}" : ""}',
            color: AppColors.primary,
          ),
        if (details.telefono != null) ...[
          const SizedBox(height: 10),
          _buildContactRow(
            icon: Icons.phone_rounded,
            label: 'Teléfono',
            value: details.telefono!,
            color: AppColors.success,
          ),
        ],
        if (details.email != null) ...[
          const SizedBox(height: 10),
          _buildContactRow(
            icon: Icons.email_rounded,
            label: 'Email',
            value: details.email!,
            color: AppColors.warning,
          ),
        ],
        if (details.website != null && details.website!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildContactRow(
            icon: Icons.language_rounded,
            label: 'Sitio web',
            value: details.website!,
            color: AppColors.accent,
          ),
        ],
      ],
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Material(
      color: widget.isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => HapticFeedback.lightImpact(),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: widget.isDark
                            ? Colors.white38
                            : Colors.grey[500],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.grey[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: widget.isDark ? Colors.white24 : Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  IconData _getVehicleIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('moto') && !lower.contains('carro')) {
      return Icons.two_wheeler_rounded;
    }
    if (lower.contains('auto') || lower.contains('carro')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('taxi')) return Icons.local_taxi_rounded;
    return Icons.directions_transit_rounded;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../conductor/services/document_upload_service.dart';
import '../../../../../core/utils/colombian_plate_utils.dart';

import 'package:viax/src/global/services/rating_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Sheet con detalle completo del conductor.
/// Diseño moderno consistente con el estilo de la app.
class DriverDetailSheet extends StatefulWidget {
  final Map<String, dynamic> conductor;
  final bool isDark;
  final ScrollController? scrollController;

  const DriverDetailSheet({
    super.key,
    required this.conductor,
    required this.isDark,
    this.scrollController,
  });

  @override
  State<DriverDetailSheet> createState() => _DriverDetailSheetState();
}

class _DriverDetailSheetState extends State<DriverDetailSheet>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingFn = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadReviews();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final conductorId =
        widget.conductor['id'] ?? widget.conductor['id_conductor'];

    if (conductorId == null) {
      if (mounted) setState(() => _isLoadingFn = false);
      return;
    }

    final idInt = conductorId is String
        ? int.tryParse(conductorId)
        : conductorId as int?;

    if (idInt == null) {
      if (mounted) setState(() => _isLoadingFn = false);
      return;
    }

    try {
      final response = await RatingService.obtenerCalificaciones(
        usuarioId: idInt,
        tipoUsuario: 'conductor',
        limit: 10,
      );

      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _reviews = List<Map<String, dynamic>>.from(
                response['calificaciones'] ?? []);
          }
          _isLoadingFn = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) {
        setState(() => _isLoadingFn = false);
        _animController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conductorNombre =
        widget.conductor['nombre'] as String? ?? 'Conductor';
    final conductorFoto = widget.conductor['foto'];
    final calificacion =
        (widget.conductor['calificacion_promedio'] as num?)?.toDouble() ??
            (widget.conductor['calificacion'] as num?)?.toDouble() ??
            5.0;
    final vehiculo =
        widget.conductor['vehiculo'] as Map<String, dynamic>?;
    final vehiculoInfo = vehiculo != null
        ? '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'.trim()
        : 'Vehículo no especificado';
    final placa = ColombianPlateUtils.formatForDisplay(
      vehiculo?['placa'] as String?,
      fallback: '',
    );

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          _buildDragHandle(),

          Flexible(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 12),

                // ── Avatar grande con borde gradiente ──
                _buildLargeAvatar(conductorFoto),

                const SizedBox(height: 16),

                // ── Nombre ──
                Text(
                  conductorNombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 10),

                // ── Rating badge ──
                Center(child: _buildRatingBadge(calificacion)),

                const SizedBox(height: 24),

                // ── Divider ──
                _buildGradientDivider(),

                const SizedBox(height: 24),

                // ── Vehículo info ──
                _buildVehicleCard(vehiculoInfo, placa, vehiculo),

                const SizedBox(height: 28),

                // ── Reseñas ──
                _buildReviewsSection(),
              ],
            ),
          ),
        ],
      ),
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

  // ── Large Avatar ────────────────────────────────────────────────────

  Widget _buildLargeAvatar(String? foto) {
    return Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.7),
              AppColors.primaryDark,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3.5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
          ),
          child: ClipOval(
            child: foto != null
                ? Image.network(
                    DocumentUploadService.getDocumentUrl(foto),
                    fit: BoxFit.cover,
                    errorBuilder: (context, err, stack) => Icon(
                      Icons.person_rounded,
                      size: 50,
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    size: 50,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Rating Badge ────────────────────────────────────────────────────

  Widget _buildRatingBadge(double calificacion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 5),
          Text(
            calificacion.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  // ── Vehicle Card ────────────────────────────────────────────────────

  Widget _buildVehicleCard(
      String vehiculoInfo, String placa, Map<String, dynamic>? vehiculo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(
              _getVehicleIcon(vehiculo?['tipo']),
              color: AppColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehiculoInfo.isNotEmpty
                      ? vehiculoInfo
                      : 'Vehículo no especificado',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (placa.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    placa,
                    style: TextStyle(
                      color:
                          widget.isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reviews Section ─────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
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
                  'Reseñas de usuarios',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            if (_reviews.length > 3)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAllReviews,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Text(
                      'Ver todas (${_reviews.length})',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Content
        if (_isLoadingFn)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 2.5,
                ),
              ),
            ),
          )
        else if (_reviews.isEmpty)
          _buildEmptyReviews()
        else
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOut,
            ),
            child: Column(
              children: _reviews
                  .take(3)
                  .map((review) => _buildReviewCard(review))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyReviews() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 36,
              color: widget.isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 10),
            Text(
              'Aún no hay reseñas',
              style: TextStyle(
                color: widget.isDark ? Colors.white38 : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final nombre = review['nombre_calificador'] ?? 'Usuario';
    final fecha = review['fecha_calificacion'] ?? '';
    final comentario = review['comentario'] as String? ?? '';
    final rating = (review['calificacion'] as num?)?.toDouble() ?? 5.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar initial
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    (nombre as String).isNotEmpty
                        ? nombre[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.warning,
                            size: 14,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              if (fecha.toString().isNotEmpty)
                Text(
                  fecha.toString().length >= 10
                      ? fecha.toString().substring(0, 10)
                      : fecha.toString(),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white30 : Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (comentario.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comentario,
              style: TextStyle(
                color: widget.isDark ? Colors.white60 : Colors.grey[600],
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Show All Reviews ────────────────────────────────────────────────

  void _showAllReviews() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.5, 0.85, 0.95],
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          widget.isDark ? Colors.white24 : Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                          'Todas las reseñas (${_reviews.length})',
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close_rounded,
                            color: widget.isDark
                                ? Colors.white54
                                : Colors.grey[500],
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      widget.isDark ? Colors.white24 : Colors.grey[300]!,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Lista completa de reseñas
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) =>
                      _buildReviewCard(_reviews[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  IconData _getVehicleIcon(String? tipo) {
    if (tipo == null) return FontAwesomeIcons.car;
    final typeLower = tipo.toLowerCase().trim();
    if (typeLower == 'motocarro') {
      return FontAwesomeIcons.vanShuttle;
    } else if (typeLower.contains('moto')) {
      return FontAwesomeIcons.motorcycle;
    } else {
      return FontAwesomeIcons.car;
    }
  }
}

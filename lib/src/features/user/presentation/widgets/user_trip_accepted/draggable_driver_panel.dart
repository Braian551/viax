import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../conductor/services/document_upload_service.dart';
import '../../../../../core/utils/colombian_plate_utils.dart';
import '../../../../../theme/app_colors.dart';

/// Panel arrastrable con información del conductor.
///
/// Diseño moderno consistente con el estilo de la app.
/// Implementa un DraggableScrollableSheet con snap points.
class DraggableDriverPanel extends StatefulWidget {
  final Map<String, dynamic>? conductor;
  final double? conductorEtaMinutes;
  final double? conductorDistanceKm;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback? onProfileTap;
  final bool isDark;
  final int unreadCount;
  
  /// Callback que notifica cambios en el tamaño del panel.
  /// Recibe el tamaño actual (0.0 - 1.0) del panel.
  final ValueChanged<double>? onSizeChanged;

  const DraggableDriverPanel({
    super.key,
    required this.conductor,
    required this.conductorEtaMinutes,
    required this.conductorDistanceKm,
    required this.onCall,
    required this.onMessage,
    this.onProfileTap,
    required this.isDark,
    this.unreadCount = 0,
    this.onSizeChanged,
  });

  @override
  State<DraggableDriverPanel> createState() => _DraggableDriverPanelState();
}

class _DraggableDriverPanelState extends State<DraggableDriverPanel> {
  final DraggableScrollableController _dragController =
      DraggableScrollableController();

  // Tamaños del panel (fracción de la pantalla)
  static const double _minSize = 0.18;
  static const double _midSize = 0.38;
  static const double _maxSize = 0.55;

  @override
  void initState() {
    super.initState();
    _dragController.addListener(_onDragUpdate);
  }

  @override
  void dispose() {
    _dragController.removeListener(_onDragUpdate);
    _dragController.dispose();
    super.dispose();
  }

  void _onDragUpdate() {
    if (_dragController.isAttached) {
      widget.onSizeChanged?.call(_dragController.size);
    }
  }

  /// Maneja el tap en el handle para animar entre tamaños
  void _handleTap() {
    if (!_dragController.isAttached) return;
    
    HapticFeedback.lightImpact();
    final current = _dragController.size;

    if (current < _midSize - 0.05) {
      _dragController.animateTo(
        _midSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else if (current < _maxSize - 0.05) {
      _dragController.animateTo(
        _maxSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _dragController.animateTo(
        _midSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conductor == null) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      controller: _dragController,
      initialChildSize: _midSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_minSize, _midSize, _maxSize],
      builder: (context, scrollController) {
        return _buildPanelContent(scrollController);
      },
    );
  }

  Widget _buildPanelContent(ScrollController scrollController) {
    final conductor = widget.conductor!;
    final nombre = conductor['nombre'] as String? ?? 'Conductor';
    final foto = conductor['foto'] as String?;
    final calificacion = (conductor['calificacion'] as num?)?.toDouble() ?? 4.5;
    final vehiculo = conductor['vehiculo'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1C1C1E)
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle de drag
            _buildDragHandle(),

            // Contenido del panel
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fila principal: avatar, nombre, botones
                  _buildDriverRow(nombre, foto, calificacion,
                      onProfileTap: widget.onProfileTap),
                  
                  const SizedBox(height: 16),
                  
                  // Divider con gradiente
                  _buildGradientDivider(),
                  
                  const SizedBox(height: 16),
                  
                  // Info del vehículo
                  if (vehiculo != null) _buildVehicleCard(vehiculo),
                  
                  // ETA y distancia
                  if (widget.conductorEtaMinutes != null || 
                      widget.conductorDistanceKm != null) ...[
                    const SizedBox(height: 12),
                    _buildEtaRow(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
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

  Widget _buildDriverRow(String nombre, String? foto, double calificacion,
      {VoidCallback? onProfileTap}) {
    return Row(
      children: [
        // Avatar y nombre (tappable para ver perfil)
        _buildTappableProfile(foto, nombre, calificacion, onProfileTap),

        // Botones de acción
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildTappableProfile(
      String? foto, String nombre, double calificacion, VoidCallback? onProfileTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (onProfileTap != null) {
            HapticFeedback.lightImpact();
            onProfileTap();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Avatar con borde gradiente
            _buildAvatar(foto),
            const SizedBox(width: 14),

            // Nombre y calificación
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: widget.isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onProfileTap != null)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: widget.isDark ? Colors.white38 : Colors.grey[400],
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildRatingBadge(calificacion),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? foto) {
    return Container(
      width: 60,
      height: 60,
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
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        ),
        child: ClipOval(
          child: foto != null && foto.isNotEmpty
              ? Image.network(
                  DocumentUploadService.getDocumentUrl(foto),
                  fit: BoxFit.cover,
                  errorBuilder: (context, err, stack) => Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                )
              : Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
        ),
      ),
    );
  }

  Widget _buildRatingBadge(double calificacion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
          const SizedBox(width: 4),
          Text(
            calificacion.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Botón llamar
        _buildActionButton(
          icon: Icons.call_rounded,
          color: AppColors.success,
          onTap: widget.onCall,
        ),
        const SizedBox(width: 10),
        // Botón mensaje con badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildActionButton(
              icon: Icons.chat_bubble_rounded,
              color: AppColors.primary,
              onTap: widget.onMessage,
            ),
            if (widget.unreadCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      widget.unreadCount > 9
                          ? '9+'
                          : widget.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

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

  Widget _buildVehicleCard(Map<String, dynamic> vehiculo) {
    final marca = vehiculo['marca'] as String? ?? '';
    final modelo = vehiculo['modelo'] as String? ?? '';
    final color = vehiculo['color'] as String? ?? '';
    final placa = ColombianPlateUtils.formatForDisplay(
      vehiculo['placa'] as String?,
    );
    final tipo = vehiculo['tipo'] as String? ?? 'auto';
    final typeLower = tipo.toLowerCase().trim();
    
    IconData iconData;
    if (typeLower == 'motocarro') {
      iconData = FontAwesomeIcons.vanShuttle;
    } else if (typeLower.contains('moto')) {
      iconData = FontAwesomeIcons.motorcycle;
    } else {
      iconData = FontAwesomeIcons.car;
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          // Icono del vehículo
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(
              iconData,
              color: AppColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Marca, modelo, color
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$marca $modelo'.trim().isEmpty
                      ? 'Vehículo'
                      : '$marca $modelo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (color.isNotEmpty)
                  Text(
                    color,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.white54 : Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),

          // Placa
          _buildPlacaBadge(placa),
        ],
      ),
    );
  }

  Widget _buildPlacaBadge(String placa) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: Text(
        placa,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: widget.isDark ? Colors.white : Colors.black87,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEtaRow() {
    return Row(
      children: [
        if (widget.conductorEtaMinutes != null)
          Expanded(
            child: _buildEtaStatCard(
              icon: Icons.access_time_rounded,
              value: '${widget.conductorEtaMinutes!.round()}',
              unit: 'min',
              label: 'Llegada',
              color: AppColors.primary,
            ),
          ),
        if (widget.conductorEtaMinutes != null &&
            widget.conductorDistanceKm != null)
          const SizedBox(width: 12),
        if (widget.conductorDistanceKm != null)
          Expanded(
            child: _buildEtaStatCard(
              icon: Icons.route_rounded,
              value: widget.conductorDistanceKm!.toStringAsFixed(1),
              unit: 'km',
              label: 'Distancia',
              color: AppColors.blue600,
            ),
          ),
      ],
    );
  }

  Widget _buildEtaStatCard({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: widget.isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark ? Colors.white54 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

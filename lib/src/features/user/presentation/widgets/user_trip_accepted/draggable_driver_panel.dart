import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';

/// Panel arrastrable con información del conductor.
///
/// Implementa un DraggableScrollableSheet con snap points para
/// permitir al usuario deslizar el panel hacia abajo y ver mejor el mapa,
/// sin poder ocultarlo completamente.
class DraggableDriverPanel extends StatefulWidget {
  final Map<String, dynamic>? conductor;
  final double? conductorEtaMinutes;
  final double? conductorDistanceKm;
  final VoidCallback onCall;
  final VoidCallback onMessage;
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
      // Si está en mínimo, ir a medio
      _dragController.animateTo(
        _midSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else if (current < _maxSize - 0.05) {
      // Si está en medio, ir a máximo
      _dragController.animateTo(
        _maxSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Si está en máximo, volver a medio
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
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
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
                  _buildDriverRow(nombre, foto, calificacion),
                  
                  const SizedBox(height: 16),
                  
                  // Divider
                  _buildDivider(),
                  
                  const SizedBox(height: 16),
                  
                  // Info del vehículo
                  if (vehiculo != null) _buildVehicleRow(vehiculo),
                  
                  // ETA y distancia
                  if (widget.conductorEtaMinutes != null || 
                      widget.conductorDistanceKm != null) ...[
                    const SizedBox(height: 16),
                    _buildEtaCard(),
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

  Widget _buildDriverRow(String nombre, String? foto, double calificacion) {
    return Row(
      children: [
        // Avatar
        _buildAvatar(foto),
        const SizedBox(width: 14),

        // Nombre y calificación
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _buildRating(calificacion),
            ],
          ),
        ),

        // Botones de acción
        _buildActionButtons(),
      ],
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
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        child: ClipOval(
          child: foto != null && foto.isNotEmpty
              ? Image.network(
                  foto,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 28,
                  ),
                )
              : Icon(Icons.person, color: AppColors.primary, size: 28),
        ),
      ),
    );
  }

  Widget _buildRating(double calificacion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              fontWeight: FontWeight.w600,
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
                          ? const Color(0xFF1E1E1E)
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
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildDivider() {
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

  Widget _buildVehicleRow(Map<String, dynamic> vehiculo) {
    final marca = vehiculo['marca'] as String? ?? '';
    final modelo = vehiculo['modelo'] as String? ?? '';
    final color = vehiculo['color'] as String? ?? '';
    final placa = vehiculo['placa'] as String? ?? '---';
    final tipo = vehiculo['tipo'] as String? ?? 'auto';
    final isMoto = tipo.toLowerCase().contains('moto');

    return Row(
      children: [
        // Icono del vehículo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withValues(alpha: 0.2),
                AppColors.accent.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isMoto ? Icons.two_wheeler : Icons.directions_car_rounded,
            color: AppColors.accent,
            size: 24,
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
                    color: widget.isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
            ],
          ),
        ),

        // Placa
        _buildPlacaBadge(placa),
      ],
    );
  }

  Widget _buildPlacaBadge(String placa) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.15)
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

  Widget _buildEtaCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (widget.conductorEtaMinutes != null)
            _buildEtaItem(
              icon: Icons.access_time_rounded,
              value: '${widget.conductorEtaMinutes!.round()}',
              unit: 'min',
              label: 'Llegada',
            ),
          if (widget.conductorEtaMinutes != null &&
              widget.conductorDistanceKm != null)
            Container(
              width: 1,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          if (widget.conductorDistanceKm != null)
            _buildEtaItem(
              icon: Icons.route_rounded,
              value: widget.conductorDistanceKm!.toStringAsFixed(1),
              unit: 'km',
              label: 'Distancia',
            ),
        ],
      ),
    );
  }

  Widget _buildEtaItem({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: widget.isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

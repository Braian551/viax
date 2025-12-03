import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/demand_zone_model.dart';

/// Widget que muestra las zonas de alta demanda en el mapa
/// Diseño único de Viax con tonalidades azules y círculos con ondas
class DemandZonesOverlay extends StatelessWidget {
  final List<DemandZone> zones;
  final bool showLabels;
  final bool animate;
  final Function(DemandZone)? onZoneTap;

  const DemandZonesOverlay({
    super.key,
    required this.zones,
    this.showLabels = true,
    this.animate = true,
    this.onZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        // Capa de círculos de zonas (de menor a mayor demanda para que las más importantes estén arriba)
        CircleLayer(
          circles: zones.map((zone) => _buildZoneCircle(zone)).toList(),
        ),

        // Capa de marcadores con indicadores de demanda
        if (showLabels)
          MarkerLayer(
            markers: zones
                .where((z) => z.hasSurge)
                .map((zone) => _buildDemandMarker(zone))
                .toList(),
          ),
      ],
    );
  }

  /// Construir círculo para una zona
  CircleMarker _buildZoneCircle(DemandZone zone) {
    // Radio proporcional: 0.5km -> ~60px en el mapa
    final baseRadius = 50.0 + (zone.demandLevel * 8.0);
    return CircleMarker(
      point: LatLng(zone.centerLat, zone.centerLng),
      radius: baseRadius,
      color: Color(zone.demandColorValue),
      borderColor: Color(zone.borderColorValue).withOpacity(0.6),
      borderStrokeWidth: 2.0,
    );
  }

  /// Construir marcador con indicador de demanda
  Marker _buildDemandMarker(DemandZone zone) {
    return Marker(
      point: LatLng(zone.centerLat, zone.centerLng),
      width: 56,
      height: 28,
      child: GestureDetector(
        onTap: () => onZoneTap?.call(zone),
        child: _DemandBadge(
          multiplier: zone.surgeMultiplier,
          demandLevel: zone.demandLevel,
          activeRequests: zone.activeRequests,
          animate: animate,
        ),
      ),
    );
  }
}

/// Badge animado que muestra el multiplicador de precio - Diseño Viax
class _DemandBadge extends StatefulWidget {
  final double multiplier;
  final int demandLevel;
  final int activeRequests;
  final bool animate;

  const _DemandBadge({
    required this.multiplier,
    required this.demandLevel,
    required this.activeRequests,
    this.animate = true,
  });

  @override
  State<_DemandBadge> createState() => _DemandBadgeState();
}

class _DemandBadgeState extends State<_DemandBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate && widget.demandLevel >= 3) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getBadgeColors();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate && widget.demandLevel >= 3
              ? _pulseAnimation.value
              : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono según demanda
                _buildDemandIcon(),
                const SizedBox(width: 3),
                // Texto del multiplicador
                Text(
                  '${widget.multiplier.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDemandIcon() {
    IconData iconData;
    double iconSize = 12;

    if (widget.demandLevel >= 5) {
      iconData = Icons.bolt;
    } else if (widget.demandLevel >= 4) {
      iconData = Icons.whatshot;
    } else if (widget.demandLevel >= 3) {
      iconData = Icons.speed;
    } else {
      iconData = Icons.trending_up;
    }

    return Icon(iconData, color: Colors.white, size: iconSize);
  }

  List<Color> _getBadgeColors() {
    // Paleta de colores azules exclusiva de Viax
    switch (widget.demandLevel) {
      case 5:
        return [
          const Color(0xFF1A237E), // Azul índigo muy oscuro
          const Color(0xFF283593), // Azul índigo
        ];
      case 4:
        return [
          const Color(0xFF1565C0), // Azul oscuro
          const Color(0xFF1976D2), // Azul
        ];
      case 3:
        return [
          const Color(0xFF1E88E5), // Azul medio
          const Color(0xFF42A5F5), // Azul claro
        ];
      case 2:
        return [
          const Color(0xFF29B6F6), // Azul cielo
          const Color(0xFF4FC3F7), // Azul cielo claro
        ];
      default:
        return [
          const Color(0xFF26C6DA), // Cyan
          const Color(0xFF4DD0E1), // Cyan claro
        ];
    }
  }
}

/// Widget para mostrar leyenda de zonas de demanda - Diseño Viax
class DemandZoneLegend extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggle;

  const DemandZoneLegend({super.key, this.isExpanded = false, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A2E).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF1976D2).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.radar, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Zonas de demanda',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A237E),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isDark ? Colors.white70 : const Color(0xFF1976D2),
                  size: 18,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 14),
              _buildLegendItem(
                colors: const [Color(0xFF1A237E), Color(0xFF283593)],
                label: 'Muy alta demanda',
                multiplier: '2.0x+',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                colors: const [Color(0xFF1565C0), Color(0xFF1976D2)],
                label: 'Alta demanda',
                multiplier: '1.5x',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                colors: const [Color(0xFF1E88E5), Color(0xFF42A5F5)],
                label: 'Media demanda',
                multiplier: '1.3x',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                colors: const [Color(0xFF29B6F6), Color(0xFF4FC3F7)],
                label: 'Demanda normal',
                multiplier: '1.0x',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Más oscuro = más ganancias',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF1565C0),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

  Widget _buildLegendItem({
    required List<Color> colors,
    required String label,
    required String multiplier,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colors[0].withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            multiplier,
            style: TextStyle(
              color: colors[0],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget de información de zona al tocar - Diseño Viax
class DemandZoneInfoCard extends StatelessWidget {
  final DemandZone zone;
  final VoidCallback? onClose;
  final VoidCallback? onNavigate;

  const DemandZoneInfoCard({
    super.key,
    required this.zone,
    this.onClose,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(zone.borderColorValue);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con gradiente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.15),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(_getZoneIcon(), color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zona de ${zone.demandLabel.toLowerCase()} demanda',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${zone.activeRequests} personas esperando',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (zone.hasSurge)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.85)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          zone.surgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'tarifa',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                if (onClose != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                      ),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Estadísticas
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.person_search,
                    value: '${zone.activeRequests}',
                    label: 'Solicitudes',
                    color: primaryColor,
                    isDark: isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.two_wheeler,
                    value: '${zone.availableDrivers}',
                    label: 'Conductores',
                    color: primaryColor,
                    isDark: isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.payments_outlined,
                    value: zone.hasSurge
                        ? '+${((zone.surgeMultiplier - 1) * 100).toInt()}%'
                        : 'Normal',
                    label: 'Ganancia',
                    color: zone.hasSurge ? primaryColor : Colors.grey,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // Botón de navegación
          if (onNavigate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNavigate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.navigation_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Ir a esta zona',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(zone.radiusKm * 1000).toInt()}m',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getZoneIcon() {
    switch (zone.demandLevel) {
      case 5:
        return Icons.bolt;
      case 4:
        return Icons.whatshot;
      case 3:
        return Icons.speed;
      case 2:
        return Icons.trending_up;
      default:
        return Icons.show_chart;
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

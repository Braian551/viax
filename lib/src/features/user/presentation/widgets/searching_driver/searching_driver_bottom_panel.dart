import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Panel inferior de búsqueda (estado, progreso, rutas y acción cancelar).
class SearchingDriverBottomPanel extends StatelessWidget {
  const SearchingDriverBottomPanel({
    super.key,
    required this.isDark,
    required this.uiStatus,
    required this.currentRadiusKm,
    required this.nearbyDriversCount,
    required this.statusTitle,
    this.statusSubtitle,
    required this.driversViewing,
    this.dynamicMessage,
    required this.direccionOrigen,
    required this.direccionDestino,
    required this.isCancelling,
    required this.miniRadar,
    required this.onCancelTap,
  });

  final bool isDark;
  final String uiStatus;
  final double currentRadiusKm;
  final int nearbyDriversCount;
  final String statusTitle;
  final String? statusSubtitle;
  final List<Map<String, dynamic>> driversViewing;
  final String? dynamicMessage;
  final String direccionOrigen;
  final String direccionDestino;
  final bool isCancelling;
  final Widget miniRadar;
  final VoidCallback onCancelTap;

  bool get _isContactingDrivers {
    return uiStatus == 'SENDING_REQUEST' ||
        uiStatus == 'DRIVER_VIEWING' ||
        uiStatus == 'ASSIGNED';
  }

  String get _primaryStatusText {
    final fallbackTitle = statusTitle.trim();

    switch (uiStatus) {
      case 'SENDING_REQUEST':
        return 'Enviando solicitud';
      case 'DRIVER_VIEWING':
        return 'Conductores revisando solicitud';
      case 'ASSIGNED':
        return 'Conductor asignado';
      case 'NO_DRIVERS':
        return 'Sin conductores disponibles';
      case 'SEARCHING':
      default:
        return fallbackTitle.isNotEmpty
            ? fallbackTitle
            : 'Buscando conductor cercano';
    }
  }

  String get _secondaryStatusText {
    final normalized = dynamicMessage?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }

    if (driversViewing.isNotEmpty) {
      final total = driversViewing.length;
      if (total == 1) {
        return '1 conductor está viendo tu solicitud';
      }
      return '$total conductores están viendo tu solicitud';
    }

    if (statusSubtitle != null && statusSubtitle!.trim().isNotEmpty) {
      return statusSubtitle!;
    }

    if (nearbyDriversCount > 0) {
      return '$nearbyDriversCount conductor${nearbyDriversCount == 1 ? '' : 'es'} cerca';
    }

    return 'Buscando en radio de ${currentRadiusKm.toStringAsFixed(0)} km';
  }

  List<_SearchStageItem> _buildStages() {
    return [
      _SearchStageItem(
        icon: Icons.radar_rounded,
        label: 'Buscando en tu zona',
        active: true,
      ),
      _SearchStageItem(
        icon: Icons.sync_rounded,
        label: 'Ampliando búsqueda',
        active: currentRadiusKm > 2.0 || uiStatus == 'SEARCHING',
      ),
      _SearchStageItem(
        icon: Icons.groups_rounded,
        label: 'Contactando conductores',
        active: _isContactingDrivers,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stages = _buildStages();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              miniRadar,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _primaryStatusText,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                            child: Text(
                              _secondaryStatusText,
                              key: ValueKey(
                                '${driversViewing.length}_${dynamicMessage ?? ''}_${statusSubtitle ?? ''}_${uiStatus}',
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stages
                  .map(
                    (stage) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: stage.active
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: stage.active
                              ? AppColors.primary.withValues(alpha: 0.55)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stage.icon,
                            size: 14,
                            color: stage.active
                                ? AppColors.primary
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stage.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: stage.active
                                  ? AppColors.primary
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: driversViewing.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    key: ValueKey('drivers_${driversViewing.length}'),
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: driversViewing.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final driver = driversViewing[index];
                        return _DriverViewingCard(
                          isDark: isDark,
                          driver: driver,
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Área de búsqueda',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  Text(
                    '${currentRadiusKm.toStringAsFixed(0)} / 10 km',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: currentRadiusKm / 10.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 20,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    const Icon(
                      Icons.location_on,
                      color: AppColors.error,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        direccionOrigen,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        direccionDestino,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: isCancelling ? null : onCancelTap,
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    AppColors.error.withValues(alpha: isCancelling ? 0.05 : 0.08),
                side: BorderSide(
                  color: isCancelling
                      ? Colors.grey.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isCancelling
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Cancelar búsqueda',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchStageItem {
  const _SearchStageItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;
}

class _DriverViewingCard extends StatelessWidget {
  const _DriverViewingCard({
    required this.isDark,
    required this.driver,
  });

  final bool isDark;
  final Map<String, dynamic> driver;

  @override
  Widget build(BuildContext context) {
    final photo = (driver['photo'] ?? '').toString().trim();
    final name = (driver['name'] ?? 'Conductor').toString();
    final rating = (driver['rating'] ?? 0).toString();
    final eta = (driver['eta'] ?? 'N/A').toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252628) : const Color(0xFF171A1F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC857),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      eta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

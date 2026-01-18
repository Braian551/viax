import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

/// Panel con efecto glassmorphism moderno
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final double blur;
  final Color? backgroundColor;
  final bool showBorder;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.blur = 20,
    this.backgroundColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  backgroundColor ??
                  (isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.8)),
              borderRadius: BorderRadius.circular(borderRadius),
              border: showBorder
                  ? Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Card con información del conductor en estilo glass moderno
class DriverInfoCard extends StatelessWidget {
  final String nombre;
  final String? foto;
  final double calificacion;
  final Map<String, dynamic>? vehiculo;
  final double? etaMinutes;
  final double? distanceKm;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final bool isDark;
  final int unreadCount;

  const DriverInfoCard({
    super.key,
    required this.nombre,
    this.foto,
    this.calificacion = 4.5,
    this.vehiculo,
    this.etaMinutes,
    this.distanceKm,
    this.onCall,
    this.onMessage,
    this.isDark = false,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final placa = vehiculo?['placa'] as String? ?? '---';
    final marca = vehiculo?['marca'] as String? ?? '';
    final modelo = vehiculo?['modelo'] as String? ?? '';
    final color = vehiculo?['color'] as String? ?? '';
    final tipo = vehiculo?['tipo'] as String? ?? 'auto';
    final isMoto = tipo.toLowerCase().contains('moto');

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          _buildHandle(),
          const SizedBox(height: 16),

          // Info del conductor y botones
          _buildDriverRow(isMoto),
          const SizedBox(height: 16),

          // Divider con gradiente
          _buildDivider(),
          const SizedBox(height: 16),

          // Info del vehículo
          _buildVehicleRow(marca, modelo, color, placa, isMoto),

          // ETA (si está disponible)
          if (etaMinutes != null || distanceKm != null) ...[
            const SizedBox(height: 16),
            _buildEtaCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.grey[400],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDriverRow(bool isMoto) {
    return Row(
      children: [
        // Avatar del conductor con efecto gradient
        _buildAvatar(),
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
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              _buildRating(),
            ],
          ),
        ),

        // Botones de acción
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
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
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        child: ClipOval(
          child: foto != null && foto!.isNotEmpty
              ? Image.network(
                  foto!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.person, color: AppColors.primary, size: 32),
                )
              : Icon(Icons.person, color: AppColors.primary, size: 32),
        ),
      ),
    );
  }

  Widget _buildRating() {
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
          onTap: onCall,
        ),
        const SizedBox(width: 10),
        // Botón mensaje con badge de no leídos
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildActionButton(
              icon: Icons.chat_bubble_rounded,
              color: AppColors.primary,
              onTap: onMessage,
            ),
            if (unreadCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
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
        onTap: onTap,
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
            isDark ? Colors.white24 : Colors.grey[300]!,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleRow(
    String marca,
    String modelo,
    String color,
    String placa,
    bool isMoto,
  ) {
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
            size: 26,
          ),
        ),
        const SizedBox(width: 14),

        // Marca, modelo, color
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$marca $modelo'.trim().isEmpty ? 'Vehículo' : '$marca $modelo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (color.isNotEmpty)
                Text(
                  color,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
            ],
          ),
        ),

        // Placa con estilo badge
        _buildPlacaBadge(placa),
      ],
    );
  }

  Widget _buildPlacaBadge(String placa) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: Text(
        placa,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black87,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildEtaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (etaMinutes != null)
            _buildEtaItem(
              icon: Icons.access_time_rounded,
              value: '${etaMinutes!.round()}',
              unit: 'min',
              label: 'Llegada',
            ),
          if (etaMinutes != null && distanceKm != null)
            Container(
              width: 1,
              height: 45,
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
          if (distanceKm != null)
            _buildEtaItem(
              icon: Icons.route_rounded,
              value: distanceKm!.toStringAsFixed(1),
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
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

/// Header con efecto glass
class GlassHeader extends StatelessWidget {
  final String statusText;
  final Color statusColor;
  final IconData statusIcon;
  final String? instructionTitle;
  final String? instructionSubtitle;
  final VoidCallback? onClose;
  final bool isDark;

  const GlassHeader({
    super.key,
    required this.statusText,
    this.statusColor = AppColors.success,
    this.statusIcon = Icons.check_circle,
    this.instructionTitle,
    this.instructionSubtitle,
    this.onClose,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? Colors.black : Colors.white,
            (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
            (isDark ? Colors.black : Colors.white).withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopRow(context),
              if (instructionTitle != null) ...[
                const SizedBox(height: 16),
                _buildInstructionCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      children: [
        // Botón cerrar
        if (onClose != null)
          Material(
            color: isDark ? Colors.white12 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            elevation: isDark ? 0 : 2,
            shadowColor: Colors.black12,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                child: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        if (onClose != null) const SizedBox(width: 12),

        // Status badge
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instructionTitle!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (instructionSubtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        instructionSubtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

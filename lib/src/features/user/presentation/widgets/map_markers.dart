import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

/// Marcador del cliente estilo Google Maps (punto azul con cono de luz/linterna)
class ClientLocationMarker extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final double heading;

  const ClientLocationMarker({
    super.key,
    required this.pulseAnimation,
    this.heading = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, _) {
        return SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cono de luz/linterna (hacia donde mira el usuario)
              Positioned(
                top: 0,
                child: Transform.rotate(
                  angle: heading * (math.pi / 180),
                  alignment: Alignment.bottomCenter,
                  child: ClipPath(
                    clipper: _BeamClipper(),
                    child: Container(
                      width: 50,
                      height: 35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary.withOpacity(0.5),
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Círculo de precisión GPS (halo exterior)
              Container(
                width: 28 + (pulseAnimation.value * 6),
                height: 28 + (pulseAnimation.value * 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(
                    0.15 * (1 - pulseAnimation.value),
                  ),
                ),
              ),

              // Punto central azul
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Marcador del punto de encuentro con ondas animadas
class PickupPointMarker extends StatelessWidget {
  final Animation<double>? waveAnimation;
  final String? label;
  final bool showLabel;
  final bool isCompact;

  const PickupPointMarker({
    super.key,
    this.waveAnimation,
    this.label,
    this.showLabel = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (waveAnimation == null) {
      return _buildStaticMarker();
    }

    return AnimatedBuilder(
      animation: waveAnimation!,
      builder: (context, _) => _buildAnimatedMarker(),
    );
  }

  Widget _buildStaticMarker() {
    final size = isCompact ? 40.0 : 48.0;
    final iconSize = isCompact ? 22.0 : 26.0;

    return SizedBox(
      width: isCompact ? 100 : 140,
      height: isCompact ? 80 : 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Marcador central
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: isCompact ? 3 : 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.place, color: Colors.white, size: iconSize),
          ),

          // Etiqueta
          if (showLabel) Positioned(top: 0, child: _buildLabel()),
        ],
      ),
    );
  }

  Widget _buildAnimatedMarker() {
    final size = isCompact ? 40.0 : 48.0;
    final iconSize = isCompact ? 22.0 : 26.0;

    return SizedBox(
      width: isCompact ? 100 : 140,
      height: isCompact ? 80 : 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ondas expansivas animadas
          ...List.generate(3, (i) {
            final delay = i / 3;
            final progress = (waveAnimation!.value + delay) % 1.0;
            final waveSize =
                (isCompact ? 35.0 : 45.0) +
                ((isCompact ? 40.0 : 55.0) * progress);
            final opacity = 0.5 * (1 - progress);
            return Container(
              width: waveSize,
              height: waveSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withOpacity(opacity),
                  width: 2.5 * (1 - progress),
                ),
              ),
            );
          }),

          // Marcador central
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: isCompact ? 3 : 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.place, color: Colors.white, size: iconSize),
          ),

          // Etiqueta
          if (showLabel)
            Positioned(top: isCompact ? 0 : 5, child: _buildLabel()),
        ],
      ),
    );
  }

  Widget _buildLabel() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            color: Colors.white,
            size: isCompact ? 10 : 12,
          ),
          const SizedBox(width: 4),
          Text(
            label ?? 'Punto de encuentro',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 9 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marcador del conductor con icono de vehículo que rota según la dirección
class DriverMarker extends StatelessWidget {
  final String? vehicleType;
  final double heading; // Dirección en grados (0-360, 0 = Norte)
  final double size;

  const DriverMarker({
    super.key,
    this.vehicleType,
    this.heading = 0.0,
    this.size = 48.0,
  });

  /// Obtiene la ruta del icono del vehículo (mirando hacia arriba)
  String _getVehicleIconPath(String type) {
    switch (type) {
      case 'moto':
        return 'assets/images/vehicles/iconvehicles/motoicon.png';
      case 'auto':
        return 'assets/images/vehicles/iconvehicles/autoicon.png';
      case 'motocarro':
        return 'assets/images/vehicles/iconvehicles/motocarroicon.png';
      default:
        // Si contiene 'moto' usa moto, si no usa auto
        if (type.toLowerCase().contains('motocarro')) {
          return 'assets/images/vehicles/iconvehicles/motocarroicon.png';
        }
        if (type.toLowerCase().contains('moto')) {
          return 'assets/images/vehicles/iconvehicles/motoicon.png';
        }
        return 'assets/images/vehicles/iconvehicles/autoicon.png';
    }
  }

  /// Icono de fallback
  IconData _getVehicleFallbackIcon(String type) {
    if (type.toLowerCase().contains('moto')) {
      return Icons.two_wheeler;
    }
    return Icons.local_taxi;
  }

  @override
  Widget build(BuildContext context) {
    final type = vehicleType ?? 'auto';
    // Convertir heading a radianes para la rotación
    // Los iconos miran hacia arriba (Norte = 0°), así que rotamos según el heading
    final rotationAngle = heading * (math.pi / 180);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sombra sutil debajo del vehículo
          Positioned(
            bottom: 2,
            child: Container(
              width: size * 0.5,
              height: size * 0.15,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Icono del vehículo rotado
          Transform.rotate(
            angle: rotationAngle,
            child: Image.asset(
              _getVehicleIconPath(type),
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback al icono si la imagen no carga
                return Transform.rotate(
                  angle: rotationAngle,
                  child: Container(
                    width: size * 0.8,
                    height: size * 0.8,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getVehicleFallbackIcon(type),
                      color: Colors.white,
                      size: size * 0.5,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomClipper para el cono de luz estilo linterna
class _BeamClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}

/// Painter para triángulo (flecha de tooltip)
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';

class BackgroundLocationDisclosureScreen extends StatelessWidget {
  const BackgroundLocationDisclosureScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Uso de Ubicación en Segundo Plano',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Viax recopila datos de ubicación para permitir el seguimiento de tus viajes y la asignación de servicios cercanos incluso cuando la aplicación está cerrada o no está en uso.',
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildFeatureItem(
                Icons.check_circle_outline,
                'Seguimiento en tiempo real para tu seguridad.',
              ),
              _buildFeatureItem(
                Icons.check_circle_outline,
                'Asignación eficiente de servicios basados en tu zona.',
              ),
              _buildFeatureItem(
                Icons.check_circle_outline,
                'Solo se activa cuando estás en modo "Conductor Activo".',
              ),
              const Spacer(),
              Text(
                'Al hacer clic en "Entendido", se te solicitará el permiso de ubicación. Selecciona "Permitir todo el tiempo" para garantizar el correcto funcionamiento como conductor.',
                style: TextStyle(fontSize: 12, color: secondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    // Solicitar permiso de ubicación
                    final status = await Permission.locationAlways.request();
                    
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        RouteNames.home,
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    'ENTENDIDO Y CONTINUAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

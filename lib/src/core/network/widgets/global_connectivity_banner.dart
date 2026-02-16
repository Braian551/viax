import 'package:flutter/material.dart';
import 'package:viax/src/core/network/connectivity_service.dart';
import 'package:viax/src/theme/app_colors.dart';

class GlobalConnectivityBanner extends StatelessWidget {
  final Widget child;

  const GlobalConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService().isOnlineListenable,
      builder: (context, isOnline, _) {
        return Stack(
          children: [
            child,
            if (!isOnline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.65)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sin internet. Algunas funciones pueden no estar disponibles.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

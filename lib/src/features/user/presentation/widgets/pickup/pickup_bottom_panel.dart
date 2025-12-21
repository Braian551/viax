import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';

class PickupBottomPanel extends StatelessWidget {
  final bool isDark;
  final double bottomPadding;
  final bool isLoadingAddress;
  final bool isRequestingTrip;
  final String pickupAddress;
  final VoidCallback onChangeHint;
  final VoidCallback onRequestTrip;

  const PickupBottomPanel({
    super.key,
    required this.isDark,
    required this.bottomPadding,
    required this.isLoadingAddress,
    required this.isRequestingTrip,
    required this.pickupAddress,
    required this.onChangeHint,
    required this.onRequestTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Punto de encuentro sugerido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Otros pasajeros han usado este punto de encuentro',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            _AddressCard(
              isDark: isDark,
              pickupAddress: pickupAddress,
              isLoadingAddress: isLoadingAddress,
              onChangeHint: onChangeHint,
            ),
            const SizedBox(height: 20),
            _RequestButton(
              isRequesting: isRequestingTrip,
              isLoadingAddress: isLoadingAddress,
              onTap: onRequestTrip,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final bool isDark;
  final String pickupAddress;
  final bool isLoadingAddress;
  final VoidCallback onChangeHint;

  const _AddressCard({
    required this.isDark,
    required this.pickupAddress,
    required this.isLoadingAddress,
    required this.onChangeHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoadingAddress)
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Obteniendo dirección...',
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  )
                else
                  Text(
                    pickupAddress,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChangeHint,
            child: const Text(
              'Cambiar',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  final bool isRequesting;
  final bool isLoadingAddress;
  final VoidCallback onTap;

  const _RequestButton({
    required this.isRequesting,
    required this.isLoadingAddress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isRequesting || isLoadingAddress ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isRequesting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Solicitar',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
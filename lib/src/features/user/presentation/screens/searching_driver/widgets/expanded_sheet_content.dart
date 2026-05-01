import 'package:flutter/material.dart';

import '../searching_driver_state.dart';

Color _sheetSurfaceColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surface.withValues(alpha: 0.94)
      : theme.colorScheme.surface;
}

Color _sheetMutedTextColor(BuildContext context, {double alpha = 0.68}) {
  return Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha);
}

Color _sheetPrimaryTint(
  BuildContext context, {
  double lightAlpha = 0.08,
  double darkAlpha = 0.16,
}) {
  final theme = Theme.of(context);
  return theme.colorScheme.primary.withValues(
    alpha: theme.brightness == Brightness.dark ? darkAlpha : lightAlpha,
  );
}

Color _sheetOutlineColor(
  BuildContext context, {
  double lightAlpha = 0.10,
  double darkAlpha = 0.22,
}) {
  final theme = Theme.of(context);
  return theme.colorScheme.onSurface.withValues(
    alpha: theme.brightness == Brightness.dark ? darkAlpha : lightAlpha,
  );
}

class ExpandedSheetContent extends StatelessWidget {
  final SearchingDriverState state;
  final String originLabel;
  final String destinationLabel;
  final String vehicleLabel;
  final String? priceLabel;
  final String paymentLabel;
  final List<String> serviceFeatures;
  final VoidCallback onCancel;
  final VoidCallback? onFareSelected;

  const ExpandedSheetContent({
    super.key,
    required this.state,
    required this.originLabel,
    required this.destinationLabel,
    required this.vehicleLabel,
    required this.paymentLabel,
    required this.serviceFeatures,
    required this.onCancel,
    this.priceLabel,
    this.onFareSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleDriver = state.visibleDriver;
    final features = serviceFeatures.isEmpty
        ? <String>['Seguimiento en tiempo real', 'Asignacion prioritaria']
        : serviceFeatures;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visibleDriver != null) ...[
          _DriverPreviewCard(driver: visibleDriver),
          const SizedBox(height: 14),
        ] else if (state.flowState == SearchFlowState.searchingDriver) ...[
          _SearchingPlaceholderCard(
            radiusLabel: state.radiusLabel,
            nearbyDriverCount: state.nearbyDriverCount,
            matchingStatus: state.matchingStatus,
            uiMessage: state.uiMessage,
          ),
          const SizedBox(height: 14),
        ],
        _InfoGrid(
          priceLabel: priceLabel,
          vehicleLabel: vehicleLabel,
          paymentLabel: paymentLabel,
          currentRadiusKm: state.currentRadiusKm,
          radiusLabel: state.radiusLabel,
          totalSecondsElapsed: state.totalSecondsElapsed,
        ),
        const SizedBox(height: 14),
        _RouteDetailCard(
          originLabel: originLabel,
          destinationLabel: destinationLabel,
        ),
        const SizedBox(height: 14),
        Text(
          'Caracteristicas del servicio',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features
              .map((feature) => _FeatureChip(label: feature))
              .toList(growable: false),
        ),
        if (state.flowState == SearchFlowState.selectingFare &&
            onFareSelected != null) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onFareSelected,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text(
                'Confirmar servicio',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(
                color: colorScheme.error.withValues(alpha: 0.35),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.close_rounded),
            label: Text(
              state.noDriverTerminal ? 'Cerrar busqueda' : 'Cancelar solicitud',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverPreviewCard extends StatelessWidget {
  final DriverPreview driver;

  const _DriverPreviewCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sheetPrimaryTint(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
            backgroundImage: driver.photoUrl != null
                ? NetworkImage(driver.photoUrl!)
                : null,
            child: driver.photoUrl == null
                ? Icon(Icons.person_rounded, color: colorScheme.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFFFC857),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          driver.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _sheetMutedTextColor(context, alpha: 0.74),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: _sheetMutedTextColor(context, alpha: 0.74),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${driver.etaMinutes} min',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _sheetMutedTextColor(context, alpha: 0.74),
                          ),
                        ),
                      ],
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

class _SearchingPlaceholderCard extends StatelessWidget {
  final String radiusLabel;
  final int nearbyDriverCount;
  final String matchingStatus;
  final String uiMessage;

  const _SearchingPlaceholderCard({
    required this.radiusLabel,
    required this.nearbyDriverCount,
    required this.matchingStatus,
    required this.uiMessage,
  });

  String _buildMessage() {
    final normalizedUiMessage = uiMessage.trim();
    if (normalizedUiMessage.isNotEmpty) {
      return normalizedUiMessage;
    }

    if (nearbyDriverCount > 0) {
      final label = nearbyDriverCount == 1
          ? '1 conductor activo cerca de ti'
          : '$nearbyDriverCount conductores activos cerca de ti';
      return '$label. Seguimos esperando la mejor respuesta disponible.';
    }

    if (matchingStatus == 'contacting_drivers') {
      return 'Ya enviamos tu solicitud y estamos esperando la primera respuesta disponible.';
    }

    return '$radiusLabel. Seguimos comparando conductores y disponibilidad en tiempo real.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sheetSurfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _sheetOutlineColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _buildMessage(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.3,
                color: _sheetMutedTextColor(context, alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final String? priceLabel;
  final String vehicleLabel;
  final String paymentLabel;
  final int currentRadiusKm;
  final String radiusLabel;
  final int totalSecondsElapsed;

  const _InfoGrid({
    required this.priceLabel,
    required this.vehicleLabel,
    required this.paymentLabel,
    required this.currentRadiusKm,
    required this.radiusLabel,
    required this.totalSecondsElapsed,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _InfoTile(
        icon: Icons.local_taxi_rounded,
        label: 'Servicio',
        value: vehicleLabel,
      ),
      _InfoTile(
        icon: Icons.radar_rounded,
        label: 'Radio actual',
        value: '$currentRadiusKm km',
      ),
      _InfoTile(icon: Icons.route_rounded, label: 'Etapa', value: radiusLabel),
      _InfoTile(
        icon: Icons.payments_rounded,
        label: 'Pago',
        value: paymentLabel,
      ),
      _InfoTile(
        icon: Icons.schedule_rounded,
        label: 'Tiempo',
        value: _formatTimer(totalSecondsElapsed),
      ),
    ];

    if (priceLabel != null && priceLabel!.trim().isNotEmpty) {
      items.insert(
        0,
        _InfoTile(
          icon: Icons.sell_rounded,
          label: 'Tarifa estimada',
          value: priceLabel!,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        const spacing = 10.0;
        final columns = maxWidth >= 520
            ? 3
            : maxWidth >= 340
            ? 2
            : 1;
        final tileWidth = columns == 1
            ? maxWidth
            : (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((item) => SizedBox(width: tileWidth, child: item))
              .toList(growable: false),
        );
      },
    );
  }

  String _formatTimer(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final restSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$restSeconds';
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _sheetSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _sheetOutlineColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _sheetPrimaryTint(
                context,
                lightAlpha: 0.10,
                darkAlpha: 0.18,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: _sheetMutedTextColor(context, alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailCard extends StatelessWidget {
  final String originLabel;
  final String destinationLabel;

  const _RouteDetailCard({
    required this.originLabel,
    required this.destinationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sheetSurfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _sheetOutlineColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 34,
                color: theme.dividerColor.withValues(alpha: 0.9),
              ),
              Icon(
                Icons.location_on_rounded,
                color: colorScheme.error,
                size: 18,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  originLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  destinationLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _sheetPrimaryTint(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

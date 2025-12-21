import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../global/models/simple_location.dart';
import '../../../../global/services/mapbox_service.dart';
import 'pickup/pickup_center_button.dart';
import 'pickup/pickup_center_pin.dart';
import 'pickup/pickup_map.dart';
import 'pickup/pickup_snapping_indicator.dart';

/// Widget de mapa con selector de ubicación estilo DiDi/Uber
/// Reutiliza los mismos componentes del selector de punto de encuentro
class MapLocationPickerSheet extends StatefulWidget {
  final SimpleLocation? initialLocation;
  final LatLng? userLocation;
  final String title;
  final Color accentColor;
  final Function(SimpleLocation) onLocationSelected;
  final VoidCallback? onClose;

  const MapLocationPickerSheet({
    super.key,
    this.initialLocation,
    this.userLocation,
    this.title = 'Seleccionar ubicación',
    this.accentColor = const Color(0xFF2196F3),
    required this.onLocationSelected,
    this.onClose,
  });

  @override
  State<MapLocationPickerSheet> createState() => _MapLocationPickerSheetState();
}

class _MapLocationPickerSheetState extends State<MapLocationPickerSheet>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late LatLng _initialCenter;
  LatLng? _clientLocation;
  LatLng? _selectedPoint;
  double _clientHeading = 0.0;

  String _address = 'Cargando dirección...';
  bool _isLoadingAddress = false;
  bool _isSnappingToRoad = false;
  bool _isMapMoving = false;

  Timer? _addressUpdateTimer;
  late AnimationController _pinBounceController;

  @override
  void initState() {
    super.initState();

    if (widget.initialLocation != null) {
      _initialCenter = widget.initialLocation!.toLatLng();
      _address = widget.initialLocation!.address;
    } else if (widget.userLocation != null) {
      _initialCenter = widget.userLocation!;
    } else {
      _initialCenter = const LatLng(6.2442, -75.5812);
    }

    _clientLocation = widget.userLocation;
    _selectedPoint = _initialCenter;

    _pinBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_initialCenter, 17);
      _snapAndUpdateAddress();
    });
  }

  @override
  void dispose() {
    _pinBounceController.dispose();
    _addressUpdateTimer?.cancel();
    super.dispose();
  }

  void _onMapMoveStart() {
    if (!_isMapMoving) {
      setState(() => _isMapMoving = true);
    }
  }

  void _onMapMoveEnd() {
    _addressUpdateTimer?.cancel();
    _addressUpdateTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final center = _mapController.camera.center;
      setState(() {
        _selectedPoint = center;
        _isMapMoving = false;
      });
      _pinBounceController.forward(from: 0);
      HapticFeedback.lightImpact();
      await _snapAndUpdateAddress();
    });
  }

  Future<void> _snapAndUpdateAddress() async {
    if (_selectedPoint == null) return;

    setState(() => _isSnappingToRoad = true);

    try {
      final snappedPoint = await _snapToNearestRoad(_selectedPoint!);

      if (mounted && snappedPoint != null) {
        final distance = const Distance().as(
          LengthUnit.Meter,
          _selectedPoint!,
          snappedPoint,
        );

        if (distance > 3) {
          _mapController.move(snappedPoint, _mapController.camera.zoom);
        }

        _selectedPoint = snappedPoint;
      }
    } catch (e) {
      debugPrint('Error snapping to road: $e');
    } finally {
      if (mounted) {
        setState(() => _isSnappingToRoad = false);
      }
    }

    await _updateAddress();
  }

  Future<LatLng?> _snapToNearestRoad(LatLng point) async {
    try {
      final snappedPoint = await MapboxService.snapToStreet(point: point);

      if (snappedPoint != null) {
        return snappedPoint;
      }

      final offsets = [
        const LatLng(0.0003, 0.0),
        const LatLng(-0.0003, 0.0),
        const LatLng(0.0, 0.0003),
        const LatLng(0.0, -0.0003),
      ];

      for (final offset in offsets) {
        final candidate = LatLng(
          point.latitude + offset.latitude,
          point.longitude + offset.longitude,
        );

        final nearbySnapped = await MapboxService.snapToStreet(point: candidate);
        if (nearbySnapped != null) {
          return nearbySnapped;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error in snapToNearestRoad: $e');
      return null;
    }
  }

  Future<void> _updateAddress() async {
    if (_selectedPoint == null) return;

    setState(() => _isLoadingAddress = true);

    try {
      final place = await MapboxService.reverseGeocodeStreetOnly(
        position: _selectedPoint!,
      );

      if (mounted) {
        setState(() {
          _address = place?.placeName ?? 'Punto en la vía';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = 'Punto en la vía';
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<void> _centerOnUserLocation() async {
    HapticFeedback.mediumImpact();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _clientLocation = latLng;
        _clientHeading = position.heading;
        _selectedPoint = latLng;
      });

      _mapController.move(latLng, 17);
      _pinBounceController.forward(from: 0);
      await _snapAndUpdateAddress();
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  bool get _canConfirm =>
      !_isMapMoving &&
      !_isLoadingAddress &&
      !_isSnappingToRoad &&
      _selectedPoint != null;

  void _confirmLocation() {
    if (!_canConfirm || _selectedPoint == null) return;

    HapticFeedback.mediumImpact();

    final location = SimpleLocation(
      latitude: _selectedPoint!.latitude,
      longitude: _selectedPoint!.longitude,
      address: _address.isEmpty ? 'Punto en la vía' : _address,
    );

    widget.onLocationSelected(location);
  }

  String _getShortAddress() {
    if (_address.isEmpty || _address == 'Cargando dirección...') {
      return 'Punto de encuentro';
    }

    final parts = _address.split(',');
    if (parts.isNotEmpty) {
      final first = parts.first.trim();
      if (first.length > 25) return '${first.substring(0, 22)}...';
      return first;
    }

    return 'Punto de encuentro';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHandle(isDark),
          _buildHeader(isDark),
          Expanded(child: _buildMapContent(isDark)),
          _buildBottomPanel(isDark),
        ],
      ),
    );
  }

  Widget _buildMapContent(bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          Positioned.fill(
            child: PickupMap(
              mapController: _mapController,
              initialCenter: _initialCenter,
              clientLocation: _clientLocation,
              clientHeading: _clientHeading,
              isDark: isDark,
              onMapMoveStart: _onMapMoveStart,
              onMapMoveEnd: _onMapMoveEnd,
            ),
          ),
          if (_isSnappingToRoad) PickupSnappingIndicator(isDark: isDark),
          IgnorePointer(
            child: PickupCenterPin(
              isMapMoving: _isMapMoving,
              pinBounceController: _pinBounceController,
              label: _isMapMoving ? 'Suelta en la calle' : _getShortAddress(),
            ),
          ),
          PickupCenterButton(
            isDark: isDark,
            onTap: _centerOnUserLocation,
            bottomOffset: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onClose?.call();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: widget.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación seleccionada',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: (_isMapMoving || _isLoadingAddress || _isSnappingToRoad)
                          ? Row(
                              key: const ValueKey('loading'),
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      widget.accentColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isSnappingToRoad
                                      ? 'Ajustando a la calle...'
                                      : 'Buscando dirección...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _address,
                              key: const ValueKey('address'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canConfirm ? _confirmLocation : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                disabledBackgroundColor: widget.accentColor.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirmar ubicación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<SimpleLocation?> showMapLocationPicker({
  required BuildContext context,
  SimpleLocation? initialLocation,
  LatLng? userLocation,
  String title = 'Seleccionar ubicación',
  Color accentColor = const Color(0xFF2196F3),
}) async {
  SimpleLocation? result;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (context) => MapLocationPickerSheet(
      initialLocation: initialLocation,
      userLocation: userLocation,
      title: title,
      accentColor: accentColor,
      onLocationSelected: (location) {
        result = location;
        Navigator.pop(context);
      },
    ),
  );

  return result;
}

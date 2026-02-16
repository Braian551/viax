import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/sound_service.dart';
import '../../../../theme/app_colors.dart';
import '../../services/conductor_service.dart';
import '../../services/trip_request_search_service.dart';
import '../models/trip_request_view.dart';
import '../widgets/conductor_searching_map.dart';
import '../widgets/request_action_panel.dart';
import 'conductor_active_trip_screen.dart';

/// Implementación limpia y modular de la búsqueda de pasajeros.
class ConductorSearchingPassengersScreen extends StatefulWidget {
  const ConductorSearchingPassengersScreen({
    super.key,
    required this.conductorId,
    required this.conductorNombre,
    required this.tipoVehiculo,
    required this.solicitud,
  });

  final int conductorId;
  final String conductorNombre;
  final String tipoVehiculo;
  final Map<String, dynamic> solicitud;

  @override
  State<ConductorSearchingPassengersScreen> createState() =>
      _ConductorSearchingPassengersScreenState();
}

class _ConductorSearchingPassengersScreenState
    extends State<ConductorSearchingPassengersScreen> {
  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  TripRequestView? _selectedRequest;
  MapboxRoute? _routeToClient;
  bool _requestProcessed = false;

  @override
  void initState() {
    super.initState();
    _selectedRequest = TripRequestView.fromMap(widget.solicitud);
    _startLocationTracking();
    _playNotificationSound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRouteToClient());
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    SoundService.stopSound();
    _setDriverUnavailable();
    super.dispose();
  }

  Future<void> _playNotificationSound() async {
    try {
      await SoundService.playRequestNotification();
    } catch (e) {
      debugPrint('Error reproduciendo sonido: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Por favor activa el GPS en tu dispositivo');
        _fallbackLocation();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showError('Permisos de ubicación denegados. Habilítalos en configuración.');
        _fallbackLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      _setCurrentLocation(position.latitude, position.longitude);

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;
        _setCurrentLocation(position.latitude, position.longitude);
        TripRequestSearchService.updateLocation(
          conductorId: widget.conductorId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
    } catch (e) {
      _showError('Error obteniendo ubicación. Usando ubicación de prueba.');
      _fallbackLocation();
    }
  }

  void _setCurrentLocation(double lat, double lng) {
    setState(() {
      _currentLocation = LatLng(lat, lng);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentLocation == null) return;
      _mapController.move(_currentLocation!, 15);
      _fetchRouteToClient();
    });
  }

  void _fallbackLocation() {
    setState(() {
      _currentLocation = const LatLng(4.6097, -74.0817);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 15);
      }
    });
  }

  Future<void> _fetchRouteToClient() async {
    if (_currentLocation == null || _selectedRequest == null) return;
    try {
      final route = await MapboxService.getRoute(
        waypoints: [
          _currentLocation!,
          _selectedRequest!.origen,
        ],
      );
      if (!mounted) return;
      setState(() => _routeToClient = route);
    } catch (e) {
      debugPrint('Error obteniendo ruta al cliente: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _acceptRequest() async {
    if (_selectedRequest == null || _requestProcessed) return;
    _requestProcessed = true;
    SoundService.stopSound();

    final solicitudData = _selectedRequest!;
    setState(() {
      _selectedRequest = null;
      _routeToClient = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final result = await TripRequestSearchService.acceptRequest(
      solicitudId: solicitudData.id,
      conductorId: widget.conductorId,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      TripRequestSearchService.markRequestAsProcessed(solicitudData.id);

      final viajeId = int.tryParse(result['viaje_id']?.toString() ?? '0');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorActiveTripScreen(
            conductorId: widget.conductorId,
            solicitudId: solicitudData.id,
            viajeId: (viajeId != null && viajeId > 0) ? viajeId : null,
            clienteId: solicitudData.clienteId,
            origenLat: solicitudData.latitudOrigen,
            origenLng: solicitudData.longitudOrigen,
            destinoLat: solicitudData.latitudDestino,
            destinoLng: solicitudData.longitudDestino,
            direccionOrigen: solicitudData.direccionOrigen,
            direccionDestino: solicitudData.direccionDestino,
            clienteNombre: solicitudData.clienteNombre,
            clienteFoto: solicitudData.clienteFoto,
            clienteCalificacion: solicitudData.clienteCalificacion,
          ),
        ),
        (route) => false,
      );
    } else {
      TripRequestSearchService.markRequestAsProcessed(solicitudData.id);
      _showError(result['message'] ?? 'Solicitud ya no disponible');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _rejectRequest() async {
    if (_selectedRequest == null || _requestProcessed) return;
    _requestProcessed = true;
    SoundService.stopSound();

    final solicitudData = _selectedRequest!;
    setState(() {
      _selectedRequest = null;
      _routeToClient = null;
    });

    TripRequestSearchService.markRequestAsProcessed(solicitudData.id);

    await TripRequestSearchService.rejectRequest(
      solicitudId: solicitudData.id,
      conductorId: widget.conductorId,
      motivo: 'Conductor rechazó',
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _setDriverUnavailable() async {
    try {
      await ConductorService.actualizarDisponibilidad(
        conductorId: widget.conductorId,
        disponible: false,
      );
    } catch (e) {
      debugPrint('Error desactivando disponibilidad: $e');
    }
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: _rejectRequest,
              child: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset('assets/images/logo.png', width: 24, height: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Buscando pasajeros',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark),
      body: Stack(
        children: [
          ConductorSearchingMap(
            mapController: _mapController,
            currentLocation: _currentLocation,
            request: _selectedRequest,
            routeToClient: _routeToClient,
            isDark: isDark,
          ),
          if (_selectedRequest != null)
            RequestActionPanel(
              request: _selectedRequest!,
              routeToClient: _routeToClient,
              currentLocation: _currentLocation,
              onAccept: _acceptRequest,
              onReject: _rejectRequest,
              onTimeout: _rejectRequest,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

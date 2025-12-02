import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/simple_location.dart';
import '../services/location_suggestion_service.dart';

/// Provider global de ubicación
/// Pre-carga la ubicación del usuario para usarla en toda la app
class LocationProvider extends ChangeNotifier {
  static final LocationProvider _instance = LocationProvider._internal();
  factory LocationProvider() => _instance;
  LocationProvider._internal();

  // Estado
  LatLng? _currentLocation;
  SimpleLocation? _currentAddress;
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _error;
  DateTime? _lastUpdate;

  // Getters
  LatLng? get currentLocation => _currentLocation;
  SimpleLocation? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  bool get hasLocation => _currentLocation != null;
  DateTime? get lastUpdate => _lastUpdate;

  /// Verifica si la ubicación está actualizada (menos de 5 minutos)
  bool get isLocationFresh {
    if (_lastUpdate == null) return false;
    return DateTime.now().difference(_lastUpdate!).inMinutes < 5;
  }

  /// Inicializa y obtiene la ubicación del usuario
  Future<void> initialize() async {
    if (_isLoading) return;
    
    // Si ya tenemos una ubicación fresca, no volver a buscar
    if (isLocationFresh && _currentLocation != null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Servicio de ubicación deshabilitado';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = 'Permiso de ubicación denegado';
          _hasPermission = false;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _error = 'Permiso de ubicación denegado permanentemente';
        _hasPermission = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _hasPermission = true;

      // Obtener posición actual
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      _lastUpdate = DateTime.now();

      // Obtener dirección en segundo plano
      _reverseGeocodeInBackground();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error obteniendo ubicación: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene la dirección de la ubicación actual en segundo plano
  Future<void> _reverseGeocodeInBackground() async {
    if (_currentLocation == null) return;

    try {
      final suggestionService = LocationSuggestionService();
      final address = await suggestionService.reverseGeocode(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      _currentAddress = SimpleLocation(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        address: address ?? 'Mi ubicación',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  /// Actualiza la ubicación forzosamente
  Future<void> refresh() async {
    _lastUpdate = null;
    await initialize();
  }

  /// Actualiza la ubicación actual manualmente
  void updateLocation(LatLng location, {SimpleLocation? address}) {
    _currentLocation = location;
    _currentAddress = address;
    _lastUpdate = DateTime.now();
    notifyListeners();
  }

  /// Limpia el estado
  void clear() {
    _currentLocation = null;
    _currentAddress = null;
    _isLoading = false;
    _error = null;
    _lastUpdate = null;
    notifyListeners();
  }
}

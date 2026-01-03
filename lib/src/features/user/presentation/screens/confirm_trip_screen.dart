import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/global/services/mapbox_service.dart';
import 'package:viax/src/global/services/app_secrets_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../../services/trip_request_service.dart';

/// Pantalla de confirmaciÃ³n de viaje
/// Muestra detalles del viaje, precio estimado y opciones de vehÃ­culo
class ConfirmTripScreen extends StatefulWidget {
  const ConfirmTripScreen({super.key});

  @override
  State<ConfirmTripScreen> createState() => _ConfirmTripScreenState();
}

class _ConfirmTripScreenState extends State<ConfirmTripScreen> {
  String _selectedVehicleType = 'moto_standard';
  double _estimatedPrice = 0.0;
  double _estimatedDistance = 0.0;
  int _estimatedTime = 0;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  MapboxRoute? _route;
  bool _isLoadingRoute = true;

  final Map<String, Map<String, dynamic>> _vehicleTypes = {
    'moto_standard': {
      'name': 'Moto EstÃ¡ndar',
      'description': 'RÃ¡pida y econÃ³mica',
      'icon': Icons.motorcycle,
      'multiplier': 1.0,
      'capacity': '1 pasajero',
    },
    'moto_premium': {
      'name': 'Moto Premium',
      'description': 'Mayor comodidad',
      'icon': Icons.motorcycle_outlined,
      'multiplier': 1.2,
      'capacity': '1 pasajero',
    },
    'moto_deluxe': {
      'name': 'Moto Deluxe',
      'description': 'MÃ¡ximo confort',
      'icon': Icons.two_wheeler,
      'multiplier': 1.5,
      'capacity': '1 pasajero',
    },
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTrip();
    });
  }

  void _calculateTrip() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args == null) return;

    _pickupLocation = args['pickup'] as LatLng?;
    _destinationLocation = args['destination'] as LatLng?;

    if (_pickupLocation != null && _destinationLocation != null) {
      // Calcular ruta usando Mapbox
      final route = await MapboxService.getRoute(
        waypoints: [_pickupLocation!, _destinationLocation!],
        profile: 'driving', // Para motos, usar driving
      );

      if (route != null) {
        setState(() {
          _route = route;
          _estimatedDistance = route.distanceKm;
          _estimatedTime = route.durationMinutes.toInt();
          _estimatedPrice = _calculatePrice(_estimatedDistance, _selectedVehicleType);
          _isLoadingRoute = false;
        });
      } else {
        // Fallback a cÃ¡lculo simulado
        setState(() {
          _estimatedDistance = 5.2;
          _estimatedTime = 15;
          _estimatedPrice = _calculatePrice(_estimatedDistance, _selectedVehicleType);
          _isLoadingRoute = false;
        });
      }
    } else {
      // Fallback
      setState(() {
        _estimatedDistance = 5.2;
        _estimatedTime = 15;
        _estimatedPrice = _calculatePrice(_estimatedDistance, _selectedVehicleType);
        _isLoadingRoute = false;
      });
    }
  }

  double _calculatePrice(double distance, String vehicleType) {
    const basePrice = 5000.0; // COP
    const pricePerKm = 2500.0; // COP
    final multiplier = _vehicleTypes[vehicleType]!['multiplier'] as double;
    
    return (basePrice + (distance * pricePerKm)) * multiplier;
  }

  void _onVehicleTypeChanged(String type) {
    setState(() {
      _selectedVehicleType = type;
      _estimatedPrice = _calculatePrice(_estimatedDistance, type);
    });
  }

  void _confirmTrip() async {
    // Obtener argumentos de la ruta
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final pickupAddress = args?['pickupAddress'] as String? ?? 'Origen';
    final destinationAddress = args?['destinationAddress'] as String? ?? 'Destino';
    
    // Obtener ID del usuario
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Usuario no identificado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00)),
              ),
              SizedBox(height: 16),
              Text(
                'Creando solicitud...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Crear solicitud de viaje
      final result = await TripRequestService.createTripRequest(
        userId: userId,
        latitudOrigen: _pickupLocation!.latitude,
        longitudOrigen: _pickupLocation!.longitude,
        direccionOrigen: pickupAddress,
        latitudDestino: _destinationLocation!.latitude,
        longitudDestino: _destinationLocation!.longitude,
        direccionDestino: destinationAddress,
        tipoServicio: 'viaje',
        tipoVehiculo: _selectedVehicleType,
        distanciaKm: _estimatedDistance,
        duracionMinutos: _estimatedTime,
        precioEstimado: _estimatedPrice,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      if (result['success'] == true) {
        final solicitudId = result['solicitud_id'];
        
        // Navegar a pantalla de espera
        final resultWaiting = await Navigator.pushNamed(
          context,
          '/user/waiting_driver',
          arguments: {
            'solicitud_id': solicitudId,
            'cliente_id': userId,
            'direccion_origen': pickupAddress,
            'direccion_destino': destinationAddress,
          },
        );

        // Si volviÃ³ de la pantalla de espera, regresar al home
        if (mounted && resultWaiting != null) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Error al crear solicitud'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final pickupAddress = args?['pickupAddress'] as String? ?? 'Origen';
    final destinationAddress = args?['destinationAddress'] as String? ?? 'Destino';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mapa con ruta
          Positioned.fill(
            child: _isLoadingRoute
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00)),
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: _pickupLocation ?? const LatLng(4.7110, -74.0721),
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: MapboxService.getTileUrl(isDarkMode: false),
                        userAgentPackageName: 'com.example.ping_go',
                        additionalOptions: {
                          'access_token': AppSecretsService.instance.mapboxToken,
                        },
                      ),
                      if (_route != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _route!.geometry,
                              color: const Color(0xFFFFFF00),
                              strokeWidth: 5.0,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_pickupLocation != null)
                            Marker(
                              point: _pickupLocation!,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          if (_destinationLocation != null)
                            Marker(
                              point: _destinationLocation!,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),

          // Panel inferior con detalles
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(pickupAddress, destinationAddress),
          ),

          // BotÃ³n de back
          Positioned(
            top: 50,
            left: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(String pickupAddress, String destinationAddress) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            border: const Border(
              top: BorderSide(color: Colors.white10, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Trip details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildTripDetails(pickupAddress, destinationAddress),
                ),

                const SizedBox(height: 16),

                // Vehicle selection
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: _vehicleTypes.entries.map((entry) {
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        child: _buildVehicleOption(entry.key, entry.value),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Price and confirm
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${_estimatedPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFFFFFF00),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$_estimatedTime min â€¢ ${_estimatedDistance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildConfirmButton(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripDetails(String pickup, String destination) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 20,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                destination,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleOption(String type, Map<String, dynamic> data) {
    final isSelected = _selectedVehicleType == type;
    final price = _calculatePrice(_estimatedDistance, type);

    return GestureDetector(
      onTap: () => _onVehicleTypeChanged(type),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: isSelected
                  ? const Color(0xFFFFFF00).withValues(alpha: 0.2)
                  : const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                  ? const Color(0xFFFFFF00)
                  : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                      ? const Color(0xFFFFFF00)
                      : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    data['icon'] as IconData,
                    color: isSelected ? Colors.black : Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['name'] as String,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFFFF00) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFFFF00) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: _confirmTrip,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFF00),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFFF00).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Solicitar',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

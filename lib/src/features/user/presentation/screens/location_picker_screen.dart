import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../../../global/models/simple_location.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(6.2442, -75.5812); // Default to Medellin
  String _address = 'Cargando dirección...';
  bool _isLoadingAddress = false;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentCenter = widget.initialPosition!;
      _getAddress(_currentCenter);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = latLng;
      });
      _mapController.move(latLng, 15);
      _getAddress(latLng);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _getAddress(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${point.latitude}&lon=${point.longitude}');
      final resp = await http.get(url, headers: {
        'User-Agent': 'ViaxApp/1.0 (student_project_demo)'
      });
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (mounted) {
          setState(() {
            _address = data['display_name'] ?? 'Dirección desconocida';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
      if (mounted) {
        setState(() => _address = 'Error obteniendo dirección');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _isMoving = true;
                    _currentCenter = position.center;
                  });
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  setState(() => _isMoving = false);
                  _getAddress(_currentCenter);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.viax',
              ),
            ],
          ),
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.location_on,
                size: 50,
                color: const Color(0xFF2196F3),
              ),
            ),
          ),
          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Bottom Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ubicación seleccionada',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isMoving ? 'Moviendo...' : _address,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isMoving || _isLoadingAddress
                        ? null
                        : () {
                            final location = SimpleLocation(
                              latitude: _currentCenter.latitude,
                              longitude: _currentCenter.longitude,
                              address: _address,
                            );
                            Navigator.pop(context, location);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirmar ubicación',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

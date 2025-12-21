// lib/src/features/map/presentation/screens/map_example_screen.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';
import '../widgets/osm_map_widget.dart';
import '../../../../widgets/quota_alert_widget.dart';
import '../../../../global/services/traffic_service.dart';

/// Pantalla de ejemplo que muestra cÃ³mo usar todas las funcionalidades
/// de Mapbox, Nominatim y TomTom integradas
class MapExampleScreen extends StatefulWidget {
  const MapExampleScreen({super.key});

  @override
  State<MapExampleScreen> createState() => _MapExampleScreenState();
}

class _MapExampleScreenState extends State<MapExampleScreen> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Actualizar estado de cuotas al cargar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MapProvider>(context, listen: false).updateQuotaStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Mapbox + APIs Gratuitas'),
        actions: [
          // Badge de estado de cuotas
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: QuotaStatusBadge()),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa principal
          OSMMapWidget(
            initialLocation: mapProvider.currentLocation ?? 
                const LatLng(4.6097, -74.0817),
            interactive: true,
            showMarkers: true,
          ),

          // Panel de controles
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Alerta de cuotas (se muestra solo si hay alertas)
                const QuotaAlertWidget(compact: true),
                
                const SizedBox(height: 16),

                // Panel de bÃºsqueda y rutas
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Campo de origen
                      TextField(
                        controller: _originController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Origen',
                          hintStyle: TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.my_location, color: Color(0xFFFFFF00)),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),

                      // Campo de destino
                      TextField(
                        controller: _destinationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Destino',
                          hintStyle: TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botones de acciÃ³n
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _calculateRoute,
                              icon: const Icon(Icons.directions),
                              label: const Text('Calcular Ruta'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFFF00),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _checkTraffic,
                            icon: const Icon(Icons.traffic),
                            label: const Text('TrÃ¡fico'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // InformaciÃ³n de la ruta
          if (mapProvider.currentRoute != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildRouteInfo(mapProvider.currentRoute!),
            ),

          // InformaciÃ³n de trÃ¡fico
          if (mapProvider.currentTraffic != null)
            Positioned(
              bottom: mapProvider.currentRoute != null ? 140 : 16,
              left: 16,
              right: 16,
              child: _buildTrafficInfo(mapProvider.currentTraffic!),
            ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // BotÃ³n para actualizar cuotas
          FloatingActionButton(
            heroTag: 'quota',
            onPressed: () async {
              await mapProvider.updateQuotaStatus();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Estado de cuotas actualizado')),
              );
            },
            backgroundColor: const Color(0xFF1A1A1A),
            child: const Icon(Icons.analytics, color: Color(0xFFFFFF00)),
          ),
          const SizedBox(height: 12),
          
          // BotÃ³n para limpiar ruta
          if (mapProvider.currentRoute != null)
            FloatingActionButton(
              heroTag: 'clear',
              onPressed: () {
                mapProvider.clearRoute();
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo(dynamic route) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ðŸ—ºï¸ InformaciÃ³n de la Ruta',
            style: TextStyle(
              color: Color(0xFFFFFF00),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip(
                Icons.straighten,
                'Distancia',
                route.formattedDistance,
              ),
              _buildInfoChip(
                Icons.access_time,
                'DuraciÃ³n',
                route.formattedDuration,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficInfo(TrafficFlow traffic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.traffic,
            color: _parseColor(traffic.color),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  traffic.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${traffic.currentSpeed.toStringAsFixed(0)} km/h',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFFFF00), size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _calculateRoute() async {
    final origin = _originController.text.trim();
    final destination = _destinationController.text.trim();

    if (origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa origen y destino')),
      );
      return;
    }

    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // Geocodificar origen
    final originSuccess = await mapProvider.geocodeAndSelect(origin);
    if (!originSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontrÃ³ el origen')),
      );
      return;
    }
    final originLocation = mapProvider.selectedLocation!;

    // Geocodificar destino
    final destinationSuccess = await mapProvider.geocodeAndSelect(destination);
    if (!destinationSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontrÃ³ el destino')),
      );
      return;
    }
    final destinationLocation = mapProvider.selectedLocation!;

    // Calcular ruta usando Mapbox
    final routeSuccess = await mapProvider.calculateRoute(
      origin: originLocation,
      destination: destinationLocation,
      profile: 'driving',
    );

    if (routeSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('âœ… Ruta calculada con Mapbox')),
      );
      
      // Actualizar cuotas
      await mapProvider.updateQuotaStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('âŒ Error calculando la ruta')),
      );
    }
  }

  Future<void> _checkTraffic() async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final location = mapProvider.currentLocation ?? 
        const LatLng(4.6097, -74.0817);

    await mapProvider.fetchTrafficInfo(location);
    await mapProvider.fetchTrafficIncidents(location, radiusKm: 5.0);

    if (mapProvider.currentTraffic != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('âœ… InformaciÃ³n de trÃ¡fico actualizada')),
      );
    }

    // Actualizar cuotas
    await mapProvider.updateQuotaStatus();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}

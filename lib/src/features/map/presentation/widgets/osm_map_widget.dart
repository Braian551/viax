import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';
import '../../../../global/services/app_secrets_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/quota_monitor_service.dart';

class OSMMapWidget extends StatefulWidget {
  final LatLng? initialLocation;
  final bool interactive;
  final Function(LatLng)? onLocationSelected;
  final Function(LatLng)? onMapMoved; // Notifica el centro actual del mapa
  final VoidCallback? onMapMoveStart;
  final VoidCallback? onMapMoveEnd;
  final bool showMarkers;

  const OSMMapWidget({
    super.key,
    this.initialLocation,
    this.interactive = true,
    this.onLocationSelected,
    this.onMapMoved,
    this.onMapMoveStart,
    this.onMapMoveEnd,
    this.showMarkers = true,
  });

  @override
  State<OSMMapWidget> createState() => _OSMMapWidgetState();
}

class _OSMMapWidgetState extends State<OSMMapWidget> {
  final MapController _mapController = MapController();
  LatLng? _currentCenter;
  bool _isMoving = false;
  Timer? _moveEndDebounce;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialLocation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si el provider tiene una selectedLocation, centrar el mapa en ella
    final mapProvider = Provider.of<MapProvider>(context);
    final selected = mapProvider.selectedLocation;
    if (selected != null && (_currentCenter == null || _currentCenter != selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(selected, 16.0);
          _currentCenter = selected;
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentCenter ?? const LatLng(4.6097, -74.0817), // BogotÃ¡ por defecto
        initialZoom: 13.0,
        maxZoom: 18.0,
        minZoom: 3.0,
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: widget.interactive ? _handleMapTap : null,
        onPositionChanged: (position, hasGesture) {
          if (!hasGesture) return;
          _currentCenter = position.center;

          // Notify start of movement once
          if (!_isMoving) {
            _isMoving = true;
            if (widget.onMapMoveStart != null) widget.onMapMoveStart!();
          }

          // Notify map moved (center is non-null per flutter_map contract)
            if (widget.onMapMoved != null) {
              widget.onMapMoved!(position.center);
            }

          // Debounce to detect movement end
          _moveEndDebounce?.cancel();
          _moveEndDebounce = Timer(const Duration(milliseconds: 200), () {
            _isMoving = false;
            if (widget.onMapMoveEnd != null) widget.onMapMoveEnd!();
          });
        },
      ),
      children: [
        // Capa de tiles de Mapbox (reemplaza OSM)
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: false),
          userAgentPackageName: 'com.viax.app',
          additionalOptions: {
            'accessToken': AppSecretsService.instance.mapboxToken,
          },
          tileProvider: NetworkTileProvider(),
          // Callback para contar tiles cargados (monitoreo de cuotas)
          tileBuilder: (context, widget, tile) {
            // Incrementar contador cada 10 tiles para no saturar
            if (tile.coordinates.z.hashCode % 10 == 0) {
              QuotaMonitorService.incrementMapboxTiles(count: 1);
            }
            return widget;
          },
        ),
        
        // Dibujar la ruta si existe
        if (mapProvider.currentRoute != null && mapProvider.currentRoute!.geometry.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: mapProvider.currentRoute!.geometry,
                strokeWidth: 5.0,
                color: const Color(0xFF4A90E2),
                borderStrokeWidth: 2.0,
                borderColor: Colors.white,
              ),
            ],
          ),

        // Marcadores de waypoints de la ruta
        if (mapProvider.routeWaypoints.isNotEmpty)
          MarkerLayer(
            markers: mapProvider.routeWaypoints.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              final isOrigin = index == 0;
              final isDestination = index == mapProvider.routeWaypoints.length - 1;
              
              return Marker(
                point: point,
                width: 40.0,
                height: 40.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: isOrigin ? Colors.green : (isDestination ? Colors.red : Colors.orange),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      isOrigin ? Icons.play_arrow : (isDestination ? Icons.flag : Icons.circle),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        
        // Marcadores opcionales (puedes ocultarlos para mostrar sÃ³lo el pin centrado)
        if (widget.showMarkers) ...[
          if (mapProvider.selectedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: mapProvider.selectedLocation!,
                  width: 40.0,
                  height: 40.0,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40.0,
                  ),
                ),
              ],
            ),

          if (mapProvider.currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: mapProvider.currentLocation!,
                  width: 30.0,
                  height: 30.0,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 30.0,
                  ),
                ),
              ],
            ),
        ],

        // Marcadores de incidentes de trÃ¡fico
        if (mapProvider.trafficIncidents.isNotEmpty)
          MarkerLayer(
            markers: mapProvider.trafficIncidents.map((incident) {
              return Marker(
                point: incident.location,
                width: 30.0,
                height: 30.0,
                child: GestureDetector(
                  onTap: () => _showIncidentInfo(context, incident),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getIncidentColor(incident.severity),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        incident.icon,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    
    mapProvider.selectLocation(point);
    
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(point);
    }
  }

  void _showIncidentInfo(BuildContext context, dynamic incident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(incident.icon),
            const SizedBox(width: 8),
            const Expanded(child: Text('Incidente de TrÃ¡fico')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              incident.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Severidad: ${incident.severityText}'),
            if (incident.from != null)
              Text('Desde: ${incident.from}'),
            if (incident.to != null)
              Text('Hasta: ${incident.to}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Color _getIncidentColor(int severity) {
    switch (severity) {
      case 0:
      case 1:
        return Colors.blue.shade700;
      case 2:
        return Colors.orange.shade700;
      case 3:
      case 4:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  void dispose() {
    _moveEndDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}

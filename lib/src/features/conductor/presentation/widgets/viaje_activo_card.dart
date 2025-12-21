import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/conductor_active_trip_screen.dart';

class ViajeActivoCard extends StatelessWidget {
  final Map<String, dynamic> viaje;

  const ViajeActivoCard({
    super.key,
    required this.viaje,
  });

  @override
  Widget build(BuildContext context) {
    final origen = viaje['origen'] ?? 'Origen desconocido';
    final destino = viaje['destino'] ?? 'Destino desconocido';
    final estado = viaje['estado'] ?? 'pendiente';
    final precio = viaje['precio_estimado']?.toString() ?? '0';
    final clienteNombre = viaje['cliente_nombre']?.toString() ?? 'Cliente';

    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;

    switch (estado) {
      case 'en_camino':
        estadoColor = Colors.blue;
        estadoIcon = Icons.directions_car;
        estadoTexto = 'En camino al origen';
        break;
      case 'en_progreso':
        estadoColor = Colors.green;
        estadoIcon = Icons.navigation;
        estadoTexto = 'En progreso';
        break;
      case 'por_iniciar':
        estadoColor = Colors.orange;
        estadoIcon = Icons.schedule;
        estadoTexto = 'Por iniciar';
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help_outline;
        estadoTexto = 'Pendiente';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, color: estadoColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          estadoTexto,
                          style: TextStyle(
                            color: estadoColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\$$precio',
                    style: const TextStyle(
                      color: Color(0xFFFFFF00),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFFFFF00),
                    radius: 20,
                      child: Text(
                        (clienteNombre.isNotEmpty ? clienteNombre[0].toUpperCase() : '?'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      clienteNombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLocationRow(Icons.circle, Colors.green, origen),
              const SizedBox(height: 12),
              _buildLocationRow(Icons.location_on, Colors.red, destino),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Llamar al cliente
                      },
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Llamar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Intentar navegar a la pantalla de ruta si tenemos coordenadas
                        final origenLat = double.tryParse(viaje['latitud_origen']?.toString() ?? viaje['origen_lat']?.toString() ?? '');
                        final origenLng = double.tryParse(viaje['longitud_origen']?.toString() ?? viaje['origen_lng']?.toString() ?? '');
                        final destinoLat = double.tryParse(viaje['latitud_destino']?.toString() ?? viaje['destino_lat']?.toString() ?? '');
                        final destinoLng = double.tryParse(viaje['longitud_destino']?.toString() ?? viaje['destino_lng']?.toString() ?? '');

                        final conductorId = int.tryParse(viaje['conductor_id']?.toString() ?? '0') ?? 0;
                        final solicitudId = int.tryParse(viaje['solicitud_id']?.toString() ?? viaje['id']?.toString() ?? '0');
                        final clienteId = int.tryParse(viaje['cliente_id']?.toString() ?? '0');

                        if (origenLat != null && origenLng != null && destinoLat != null && destinoLng != null && conductorId > 0) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConductorActiveTripScreen(
                                conductorId: conductorId,
                                solicitudId: solicitudId,
                                clienteId: clienteId,
                                origenLat: origenLat,
                                origenLng: origenLng,
                                destinoLat: destinoLat,
                                destinoLng: destinoLng,
                                direccionOrigen: viaje['direccion_origen']?.toString() ?? origen,
                                direccionDestino: viaje['direccion_destino']?.toString() ?? destino,
                                clienteNombre: clienteNombre,
                                clienteFoto: viaje['cliente_foto']?.toString(),
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No hay datos suficientes para navegar el viaje'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Navegar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFF00),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

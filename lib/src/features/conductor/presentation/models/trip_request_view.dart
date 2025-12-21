import 'package:latlong2/latlong.dart';

/// Vista tipada de la solicitud de viaje para evitar uso de mapas dinámicos.
class TripRequestView {
  TripRequestView({
    required this.id,
    required this.latitudOrigen,
    required this.longitudOrigen,
    required this.latitudDestino,
    required this.longitudDestino,
    required this.distanciaKm,
    required this.precioEstimado,
    required this.duracionMinutos,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.clienteNombre,
  });


  final int id;
  final double latitudOrigen;
  final double longitudOrigen;
  final double latitudDestino;
  final double longitudDestino;
  final double distanciaKm;
  final double precioEstimado;
  final int duracionMinutos;
  final String direccionOrigen;
  final String direccionDestino;
  final String? clienteNombre;

  LatLng get origen => LatLng(latitudOrigen, longitudOrigen);
  LatLng get destino => LatLng(latitudDestino, longitudDestino);

  factory TripRequestView.fromMap(Map<String, dynamic> raw) {
    double _toDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int _toInt(dynamic value) {
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return TripRequestView(
      id: _toInt(raw['id']),
      latitudOrigen: _toDouble(raw['latitud_origen']),
      longitudOrigen: _toDouble(raw['longitud_origen']),
      latitudDestino: _toDouble(raw['latitud_destino']),
      longitudDestino: _toDouble(raw['longitud_destino']),
      distanciaKm: _toDouble(raw['distancia_km']),
      precioEstimado: _toDouble(raw['precio_estimado']),
      duracionMinutos: _toInt(raw['duracion_minutos']),
      direccionOrigen: raw['direccion_origen']?.toString() ?? 'Sin dirección',
      direccionDestino: raw['direccion_destino']?.toString() ?? 'Sin dirección',
      clienteNombre: raw['cliente_nombre']?.toString(),
    );
  }
}

import 'package:latlong2/latlong.dart';
import '../../../../global/services/auth/user_service.dart';

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
    this.clienteId,
    this.clienteNombre,
    this.clienteFoto,
    this.clienteTelefono,
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
  final int? clienteId;
  final String? clienteNombre;
  final String? clienteFoto;
  final String? clienteTelefono;

  LatLng get origen => LatLng(latitudOrigen, longitudOrigen);
  LatLng get destino => LatLng(latitudDestino, longitudDestino);

  factory TripRequestView.fromMap(Map<String, dynamic> raw) {
    double _toDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int _toInt(dynamic value) {
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? _toIntOrNull(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    return TripRequestView(
      id: _toInt(raw['id']),
      latitudOrigen: _toDouble(raw['latitud_origen'] ?? raw['latitud_recogida']),
      longitudOrigen: _toDouble(raw['longitud_origen'] ?? raw['longitud_recogida']),
      latitudDestino: _toDouble(raw['latitud_destino']),
      longitudDestino: _toDouble(raw['longitud_destino']),
      distanciaKm: _toDouble(raw['distancia_km'] ?? raw['distancia_estimada']),
      precioEstimado: _toDouble(raw['precio_estimado']),
      duracionMinutos: _toInt(raw['duracion_minutos'] ?? raw['tiempo_estimado']),
      direccionOrigen: (raw['direccion_origen'] ?? raw['direccion_recogida'])?.toString() ?? 'Sin dirección',
      direccionDestino: raw['direccion_destino']?.toString() ?? 'Sin dirección',
      clienteId: _toIntOrNull(raw['cliente_id']),
      clienteNombre: (raw['cliente_nombre'] ?? raw['nombre_usuario'])?.toString(),
      // Procesar foto con R2 URL si es necesario
      clienteFoto: _processPhotoUrl((raw['cliente_foto'] ?? raw['foto_usuario'])?.toString()),
      clienteTelefono: (raw['cliente_telefono'] ?? raw['telefono_usuario'])?.toString(),
    );
  }

  /// Procesa la URL de la foto para manejar correctamente fotos de R2
  static String? _processPhotoUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    // Si ya es una URL completa, retornarla
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    // Si es un key de R2, convertirla a URL completa
    return UserService.getR2ImageUrl(rawUrl);
  }
}

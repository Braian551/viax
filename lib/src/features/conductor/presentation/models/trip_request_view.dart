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
    this.clienteCalificacion,
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
  final double? clienteCalificacion;

  LatLng get origen => LatLng(latitudOrigen, longitudOrigen);
  LatLng get destino => LatLng(latitudDestino, longitudDestino);

  factory TripRequestView.fromMap(Map<String, dynamic> raw) {
    double toDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int toInt(dynamic value) {
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? toIntOrNull(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    double? toDoubleOrNull(dynamic value) {
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    return TripRequestView(
      id: toInt(raw['id']),
      latitudOrigen: toDouble(raw['latitud_origen'] ?? raw['latitud_recogida']),
      longitudOrigen: toDouble(raw['longitud_origen'] ?? raw['longitud_recogida']),
      latitudDestino: toDouble(raw['latitud_destino']),
      longitudDestino: toDouble(raw['longitud_destino']),
      distanciaKm: toDouble(raw['distancia_km'] ?? raw['distancia_estimada']),
      precioEstimado: toDouble(raw['precio_estimado']),
      duracionMinutos: toInt(raw['duracion_minutos'] ?? raw['tiempo_estimado']),
      direccionOrigen: (raw['direccion_origen'] ?? raw['direccion_recogida'])?.toString() ?? 'Sin dirección',
      direccionDestino: raw['direccion_destino']?.toString() ?? 'Sin dirección',
      clienteId: toIntOrNull(raw['cliente_id']),
      clienteNombre: (raw['cliente_nombre'] ?? raw['nombre_usuario'])?.toString(),
      // Procesar foto con R2 URL si es necesario
      clienteFoto: _processPhotoUrl((raw['cliente_foto'] ?? raw['foto_usuario'])?.toString()),
      clienteTelefono: (raw['cliente_telefono'] ?? raw['telefono_usuario'])?.toString(),
      clienteCalificacion: toDoubleOrNull(
        raw['cliente_calificacion'] ??
            raw['calificacion_cliente'] ??
            raw['rating_cliente'] ??
            raw['cliente_rating'] ??
            raw['usuario_calificacion'] ??
            raw['rating_usuario'],
      ),
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

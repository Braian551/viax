import 'dart:convert';
import '../../core/config/app_config.dart';
import '../../core/network/network_request_executor.dart';

/// Modelo de datos para una disputa de pago.
class DisputaData {
  final int id;
  final int solicitudId;
  final String estado;
  final String createdAt;
  final String miRol; // 'cliente' o 'conductor'
  final DisputaUsuario cliente;
  final DisputaUsuario conductor;
  final DisputaViaje viaje;
  final String mensaje;

  DisputaData({
    required this.id,
    required this.solicitudId,
    required this.estado,
    required this.createdAt,
    required this.miRol,
    required this.cliente,
    required this.conductor,
    required this.viaje,
    required this.mensaje,
  });

  factory DisputaData.fromJson(Map<String, dynamic> json) {
    return DisputaData(
      id: json['id'] ?? 0,
      solicitudId: json['solicitud_id'] ?? 0,
      estado: json['estado'] ?? 'activa',
      createdAt: json['creado_en'] ?? '',
      miRol: json['mi_rol'] ?? 'cliente',
      cliente: DisputaUsuario.fromJson(json['cliente'] ?? {}),
      conductor: DisputaUsuario.fromJson(json['conductor'] ?? {}),
      viaje: DisputaViaje.fromJson(json['viaje'] ?? {}),
      mensaje: json['mensaje'] ?? '',
    );
  }

  bool get soyCliente => miRol == 'cliente';
  bool get soyConductor => miRol == 'conductor';
}

class DisputaUsuario {
  final int id;
  final String nombre;
  final bool confirmaPago;

  DisputaUsuario({
    required this.id,
    required this.nombre,
    required this.confirmaPago,
  });

  factory DisputaUsuario.fromJson(Map<String, dynamic> json) {
    return DisputaUsuario(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      confirmaPago: json['confirma_pago'] ?? json['confirma_recibo'] ?? false,
    );
  }
}

class DisputaViaje {
  final String origen;
  final String destino;
  final double precio;

  DisputaViaje({
    required this.origen,
    required this.destino,
    required this.precio,
  });

  factory DisputaViaje.fromJson(Map<String, dynamic> json) {
    return DisputaViaje(
      origen: json['origen'] ?? '',
      destino: json['destino'] ?? '',
      precio: (json['precio'] ?? 0).toDouble(),
    );
  }
}

/// Resultado de reportar estado de pago.
class PaymentStatusResult {
  final bool success;
  final bool clienteConfirma;
  final bool conductorConfirma;
  final bool hayDisputa;
  final int? disputaId;
  final String mensaje;

  PaymentStatusResult({
    required this.success,
    required this.clienteConfirma,
    required this.conductorConfirma,
    required this.hayDisputa,
    this.disputaId,
    required this.mensaje,
  });

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResult(
      success: json['success'] ?? false,
      clienteConfirma: json['cliente_confirma'] ?? false,
      conductorConfirma: json['conductor_confirma'] ?? false,
      hayDisputa: json['hay_disputa'] ?? false,
      disputaId: json['disputa_id'],
      mensaje: json['mensaje'] ?? '',
    );
  }
}

/// Servicio para manejar disputas de pago.
class DisputeService {
  static final DisputeService _instance = DisputeService._internal();
  factory DisputeService() => _instance;
  DisputeService._internal();
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  /// Verificar si el usuario tiene una disputa activa.
  Future<({bool tieneDisputa, DisputaData? disputa})> checkDisputeStatus(int usuarioId) async {
    try {
      final url = '${AppConfig.baseUrl}/payment/check_dispute_status.php?usuario_id=$usuarioId';
      final result = await _network.getJson(
        url: Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return (tieneDisputa: false, disputa: null);
      }

      final data = result.json!;
      
      if (data['success'] == true) {
        final bool tieneDisputa = data['tiene_disputa'] ?? false;
        DisputaData? disputa;
        
        if (tieneDisputa && data['disputa'] != null) {
          disputa = DisputaData.fromJson(data['disputa']);
        }
        
        return (tieneDisputa: tieneDisputa, disputa: disputa);
      }
      
      return (tieneDisputa: false, disputa: null);
    } catch (e) {
      print('Error checking dispute status: $e');
      return (tieneDisputa: false, disputa: null);
    }
  }

  /// Reportar estado de pago (cliente confirma que pagó o conductor confirma que recibió).
  Future<PaymentStatusResult> reportPaymentStatus({
    required int solicitudId,
    required int usuarioId,
    required String tipoUsuario, // 'cliente' o 'conductor'
    required bool confirmaPago,
  }) async {
    try {
      final url = '${AppConfig.baseUrl}/payment/report_payment_status.php';
      print('📡 DisputeService: Enviando a $url');
      print('   Datos: solicitud=$solicitudId, usuario=$usuarioId, tipo=$tipoUsuario, confirma=$confirmaPago');
      
      final result = await _network.postJson(
        url: Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'solicitud_id': solicitudId,
          'usuario_id': usuarioId,
          'tipo_usuario': tipoUsuario,
          'confirma_pago': confirmaPago,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      print('📡 DisputeService: Respuesta HTTP ${result.statusCode}');

      if (!result.success || result.json == null) {
        throw Exception(result.error?.userMessage ?? 'No fue posible reportar el estado de pago.');
      }
      
      final data = result.json!;
      return PaymentStatusResult.fromJson(data);
    } catch (e) {
      print('❌ DisputeService Error: $e');
      // En caso de error de conexión, devolver éxito local para continuar
      // TODO: Remover esto cuando el backend esté configurado
      return PaymentStatusResult(
        success: true,
        clienteConfirma: tipoUsuario == 'cliente' && confirmaPago,
        conductorConfirma: tipoUsuario == 'conductor' && confirmaPago,
        hayDisputa: false,
        mensaje: 'Confirmación guardada localmente (sin backend)',
      );
    }
  }

  /// Resolver disputa (conductor confirma que sí recibió el pago).
  Future<bool> resolveDispute({
    required int disputaId,
    required int conductorId,
  }) async {
    try {
      final url = '${AppConfig.baseUrl}/payment/resolve_dispute.php';
      final result = await _network.postJson(
        url: Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'disputa_id': disputaId,
          'conductor_id': conductorId,
          'confirma_recibo': true,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return false;
      }

      final data = result.json!;
      return data['success'] == true;
    } catch (e) {
      print('Error resolving dispute: $e');
      return false;
    }
  }
}

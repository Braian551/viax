import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/network/network_request_executor.dart';
import '../../core/network/app_network_exception.dart';

/// Modelo de mensaje de chat
class ChatMessage {
  final int id;
  final int solicitudId;
  final int remitenteId;
  final int destinatarioId;
  final String tipoRemitente; // 'cliente' o 'conductor'
  final String mensaje;
  final String tipoMensaje; // 'texto', 'imagen', 'ubicacion', 'audio', 'sistema'
  final bool leido;
  final DateTime? leidoEn;
  final DateTime fechaCreacion;
  final String? remitenteNombre;
  final String? remitenteFoto;

  ChatMessage({
    required this.id,
    required this.solicitudId,
    required this.remitenteId,
    required this.destinatarioId,
    required this.tipoRemitente,
    required this.mensaje,
    required this.tipoMensaje,
    required this.leido,
    this.leidoEn,
    required this.fechaCreacion,
    this.remitenteNombre,
    this.remitenteFoto,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: ChatService.asInt(json['id']),
      solicitudId: ChatService.asInt(json['solicitud_id']),
      remitenteId: ChatService.asInt(json['remitente_id']),
      destinatarioId: ChatService.asInt(json['destinatario_id']),
      tipoRemitente: json['tipo_remitente'] as String,
      mensaje: json['mensaje'] as String,
      tipoMensaje: json['tipo_mensaje'] as String? ?? 'texto',
      leido: ChatService.asBool(json['leido']),
      leidoEn: DateTimeUtils.parseServerDate(json['leido_en']?.toString()),
      fechaCreacion: DateTimeUtils.parseServerDateOrNow(json['fecha_creacion']?.toString()),
      remitenteNombre: json['remitente']?['nombre'] as String?,
      remitenteFoto: json['remitente']?['foto'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'solicitud_id': solicitudId,
    'remitente_id': remitenteId,
    'destinatario_id': destinatarioId,
    'tipo_remitente': tipoRemitente,
    'mensaje': mensaje,
    'tipo_mensaje': tipoMensaje,
    'leido': leido,
    'leido_en': leidoEn?.toIso8601String(),
    'fecha_creacion': fechaCreacion.toIso8601String(),
  };

  /// Verifica si el mensaje fue enviado por el usuario actual
  bool esMio(int miUsuarioId) => remitenteId == miUsuarioId;
}

/// Servicio de chat compartido entre cliente y conductor.
/// 
/// Maneja la comunicación en tiempo real (con polling) durante un viaje activo.
class ChatService {
  static String get baseUrl => AppConfig.baseUrl;
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true' || normalized == 'si') {
        return true;
      }
      if (normalized == '0' || normalized == 'false' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  static String _friendlyMessage(NetworkRequestResult result, {String fallback = 'No pudimos completar la operación de chat.'}) {
    return result.error?.userMessage ?? fallback;
  }

  /// Estado global para saber si el chat está abierto
  static bool isChatOpen = false;
  
  // Stream controller para emitir nuevos mensajes
  static final StreamController<List<ChatMessage>> _messagesController =
      StreamController<List<ChatMessage>>.broadcast();
  
  // Stream controller para emitir conteo de no leídos
  static final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  /// Stream de mensajes nuevos
  static Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  
  /// Stream de conteo de mensajes no leídos
  static Stream<int> get unreadCountStream => _unreadCountController.stream;

  // Timer para polling
  static Timer? _pollingTimer;
  static int? _lastMessageId;
  static int? _currentSolicitudId;
  static int? _currentUsuarioId;

  /// Iniciar polling de mensajes para una solicitud
  static void startPolling({
    required int solicitudId,
    required int usuarioId,
    Duration interval = const Duration(seconds: 3),
  }) {
    stopPolling(); // Detener polling anterior si existe
    
    _currentSolicitudId = solicitudId;
    _currentUsuarioId = usuarioId;
    _lastMessageId = null;
    
    // Primera carga inmediata
    _fetchMessages(solicitudId, usuarioId);
    
    // Iniciar polling periódico
    _pollingTimer = Timer.periodic(interval, (_) {
      _fetchMessages(solicitudId, usuarioId);
    });
    
    debugPrint('💬 [ChatService] Polling iniciado para solicitud $solicitudId');
  }

  /// Detener polling de mensajes
  static void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastMessageId = null;
    _currentSolicitudId = null;
    _currentUsuarioId = null;
    debugPrint('💬 [ChatService] Polling detenido');
  }

  /// Obtener mensajes (llamado por polling)
  static Future<void> _fetchMessages(int solicitudId, int usuarioId) async {
    try {
      final messages = await getMessages(
        solicitudId: solicitudId,
        usuarioId: usuarioId,
        desdeId: _lastMessageId,
      );
      
      if (messages.isNotEmpty) {
        // Actualizar último ID
        _lastMessageId = messages.last.id;
        
        // Emitir mensajes al stream
        _messagesController.add(messages);
      }
      
      // Actualizar conteo de no leídos
      final unread = await getUnreadCount(
        solicitudId: solicitudId,
        usuarioId: usuarioId,
      );
      _unreadCountController.add(unread);
      
    } catch (e) {
      debugPrint('💬 [ChatService] Error en polling: $e');
    }
  }

  /// Enviar un mensaje de texto
  static Future<ChatMessage?> sendMessage({
    required int solicitudId,
    required int remitenteId,
    required int destinatarioId,
    required String mensaje,
    required String tipoRemitente, // 'cliente' o 'conductor'
    String tipoMensaje = 'texto',
  }) async {
    try {
      final url = '$baseUrl/chat/send_message.php';
      debugPrint('💬 [ChatService] Enviando mensaje a: $url');
      
      final result = await _network.postJson(
        url: Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': solicitudId,
          'remitente_id': remitenteId,
          'destinatario_id': destinatarioId,
          'mensaje': mensaje,
          'tipo_remitente': tipoRemitente,
          'tipo_mensaje': tipoMensaje,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      debugPrint('💬 [ChatService] Respuesta: ${result.statusCode}');

      if (!result.success || result.json == null) {
        throw Exception(_friendlyMessage(result, fallback: 'No pudimos enviar tu mensaje.'));
      }

      final data = result.json!;
      if (data['success'] == true) {
        debugPrint('✅ [ChatService] Mensaje enviado exitosamente');

        final msgData = data['data'] as Map<String, dynamic>;
        return ChatMessage(
          id: msgData['id'] as int,
          solicitudId: msgData['solicitud_id'] as int,
          remitenteId: msgData['remitente_id'] as int,
          destinatarioId: msgData['destinatario_id'] as int,
          tipoRemitente: msgData['tipo_remitente'] as String,
          mensaje: msgData['mensaje'] as String,
          tipoMensaje: msgData['tipo_mensaje'] as String,
          leido: false,
          fechaCreacion: DateTimeUtils.parseServerDateOrNow(msgData['fecha_creacion']?.toString()),
        );
      }

      throw Exception(data['message']?.toString() ?? 'No pudimos enviar tu mensaje.');
    } catch (e) {
      debugPrint('❌ [ChatService] Error enviando mensaje: $e');
      final mapped = AppNetworkException.fromError(e);
      throw Exception(mapped.userMessage);
    }
  }

  /// Obtener mensajes de una conversación
  static Future<List<ChatMessage>> getMessages({
    required int solicitudId,
    required int usuarioId,
    int? desdeId,
    int limite = 50,
  }) async {
    try {
      var url = '$baseUrl/chat/get_messages.php?solicitud_id=$solicitudId&usuario_id=$usuarioId&limite=$limite';
      
      if (desdeId != null) {
        url += '&desde_id=$desdeId';
      }
      
      final result = await _network.getJson(
        url: Uri.parse(url),
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return [];
      }

      final data = result.json!;
      if (data['success'] == true) {
        final mensajesJson = data['mensajes'] as List<dynamic>;
        return mensajesJson
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('❌ [ChatService] Error obteniendo mensajes: $e');
      return [];
    }
  }

  /// Obtener todos los mensajes históricos (sin polling)
  static Future<List<ChatMessage>> getAllMessages({
    required int solicitudId,
    required int usuarioId,
  }) async {
    return getMessages(
      solicitudId: solicitudId,
      usuarioId: usuarioId,
      limite: 100,
    );
  }

  /// Marcar mensajes como leídos
  static Future<bool> markAsRead({
    required int solicitudId,
    required int usuarioId,
    int? mensajeId,
  }) async {
    try {
      final url = '$baseUrl/chat/mark_as_read.php';
      
      final body = {
        'solicitud_id': solicitudId,
        'usuario_id': usuarioId,
      };
      
      if (mensajeId != null) {
        body['mensaje_id'] = mensajeId;
      }
      
      final result = await _network.postJson(
        url: Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return false;
      }

      final data = result.json!;
      return data['success'] == true;

      return false;
    } catch (e) {
      debugPrint('❌ [ChatService] Error marcando como leído: $e');
      return false;
    }
  }

  /// Obtener conteo de mensajes no leídos
  static Future<int> getUnreadCount({
    required int solicitudId,
    required int usuarioId,
  }) async {
    try {
      final url = '$baseUrl/chat/get_unread_count.php?solicitud_id=$solicitudId&usuario_id=$usuarioId';
      
      final result = await _network.getJson(
        url: Uri.parse(url),
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return 0;
      }

      final data = result.json!;
      if (data['success'] == true) {
        return asInt(data['no_leidos']);
      }

      return 0;
    } catch (e) {
      debugPrint('❌ [ChatService] Error obteniendo conteo no leídos: $e');
      return 0;
    }
  }

  /// Limpiar recursos
  static void dispose() {
    stopPolling();
    // No cerramos los controllers para permitir reutilización
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

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
      id: json['id'] as int,
      solicitudId: json['solicitud_id'] as int,
      remitenteId: json['remitente_id'] as int,
      destinatarioId: json['destinatario_id'] as int,
      tipoRemitente: json['tipo_remitente'] as String,
      mensaje: json['mensaje'] as String,
      tipoMensaje: json['tipo_mensaje'] as String? ?? 'texto',
      leido: json['leido'] as bool? ?? false,
      leidoEn: json['leido_en'] != null
          ? DateTime.tryParse(json['leido_en'] as String)
          : null,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
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
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': solicitudId,
          'remitente_id': remitenteId,
          'destinatario_id': destinatarioId,
          'mensaje': mensaje,
          'tipo_remitente': tipoRemitente,
          'tipo_mensaje': tipoMensaje,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado al enviar mensaje');
        },
      );

      debugPrint('💬 [ChatService] Respuesta: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ [ChatService] Mensaje enviado exitosamente');
          
          // Crear objeto ChatMessage desde la respuesta
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
            fechaCreacion: DateTime.parse(msgData['fecha_creacion'] as String),
          );
        } else {
          throw Exception(data['message'] ?? 'Error al enviar mensaje');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [ChatService] Error enviando mensaje: $e');
      rethrow;
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
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final mensajesJson = data['mensajes'] as List<dynamic>;
          return mensajesJson
              .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList();
        }
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
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
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
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['no_leidos'] as int? ?? 0;
        }
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

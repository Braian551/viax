import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';

/// Modelo de categoría de soporte
class SupportCategory {
  final int id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String icono;
  final String color;

  SupportCategory({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.icono,
    required this.color,
  });

  factory SupportCategory.fromJson(Map<String, dynamic> json) {
    return SupportCategory(
      id: json['id'] ?? 0,
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      icono: json['icono'] ?? 'support',
      color: json['color'] ?? '#2196F3',
    );
  }
}

/// Modelo de ticket de soporte
class SupportTicket {
  final int id;
  final String numeroTicket;
  final String asunto;
  final String estado;
  final String prioridad;
  final String categoriaCodigo;
  final String categoriaNombre;
  final String categoriaIcono;
  final String categoriaColor;
  final int mensajesNoLeidos;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket({
    required this.id,
    required this.numeroTicket,
    required this.asunto,
    required this.estado,
    required this.prioridad,
    required this.categoriaCodigo,
    required this.categoriaNombre,
    required this.categoriaIcono,
    required this.categoriaColor,
    required this.mensajesNoLeidos,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] ?? 0,
      numeroTicket: json['numero_ticket'] ?? '',
      asunto: json['asunto'] ?? '',
      estado: json['estado'] ?? 'abierto',
      prioridad: json['prioridad'] ?? 'normal',
      categoriaCodigo: json['categoria_codigo'] ?? '',
      categoriaNombre: json['categoria_nombre'] ?? '',
      categoriaIcono: json['categoria_icono'] ?? 'support',
      categoriaColor: json['categoria_color'] ?? '#2196F3',
      mensajesNoLeidos: json['mensajes_no_leidos'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get estadoDisplay {
    switch (estado) {
      case 'abierto':
        return 'Abierto';
      case 'en_progreso':
        return 'En progreso';
      case 'esperando_usuario':
        return 'Esperando respuesta';
      case 'resuelto':
        return 'Resuelto';
      case 'cerrado':
        return 'Cerrado';
      default:
        return estado;
    }
  }
}

/// Modelo de mensaje de ticket
class TicketMessage {
  final int id;
  final String mensaje;
  final bool esAgente;
  final String? remitenteNombre;
  final DateTime createdAt;

  TicketMessage({
    required this.id,
    required this.mensaje,
    required this.esAgente,
    this.remitenteNombre,
    required this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: json['id'] ?? 0,
      mensaje: json['mensaje'] ?? '',
      esAgente: json['es_agente'] ?? false,
      remitenteNombre: json['remitente_nombre'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Servicio de soporte
class SupportService {
  static final String _baseUrl = '${AppConfig.baseUrl}/support';

  /// Obtener categorías de soporte
  static Future<List<SupportCategory>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/get_categories.php'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> categorias = data['categorias'] ?? [];
          return categorias.map((c) => SupportCategory.fromJson(c)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error obteniendo categorías: $e');
      return [];
    }
  }

  /// Crear un nuevo ticket
  static Future<Map<String, dynamic>?> createTicket({
    required int userId,
    required int categoryId,
    required String subject,
    String? description,
    int? tripId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create_ticket.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usuario_id': userId,
          'categoria_id': categoryId,
          'asunto': subject,
          'descripcion': description,
          'viaje_id': tripId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['ticket'];
        }
      }
      return null;
    } catch (e) {
      print('Error creando ticket: $e');
      return null;
    }
  }

  /// Obtener tickets del usuario
  static Future<List<SupportTicket>> getTickets({
    required int userId,
    String? estado,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'usuario_id': userId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (estado != null) {
        queryParams['estado'] = estado;
      }

      final uri = Uri.parse('$_baseUrl/get_tickets.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> tickets = data['tickets'] ?? [];
          return tickets.map((t) => SupportTicket.fromJson(t)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error obteniendo tickets: $e');
      return [];
    }
  }

  /// Obtener mensajes de un ticket
  static Future<Map<String, dynamic>?> getTicketMessages({
    required int ticketId,
    required int userId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/get_ticket_messages.php')
          .replace(queryParameters: {
        'ticket_id': ticketId.toString(),
        'usuario_id': userId.toString(),
      });

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> mensajes = data['mensajes'] ?? [];
          return {
            'ticket': data['ticket'],
            'mensajes': mensajes.map((m) => TicketMessage.fromJson(m)).toList(),
          };
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo mensajes: $e');
      return null;
    }
  }

  /// Enviar mensaje a un ticket
  static Future<TicketMessage?> sendMessage({
    required int ticketId,
    required int userId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send_message.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'ticket_id': ticketId,
          'usuario_id': userId,
          'mensaje': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['mensaje'] != null) {
          return TicketMessage.fromJson(data['mensaje']);
        }
      }
      return null;
    } catch (e) {
      print('Error enviando mensaje: $e');
      return null;
    }
  }

  /// Solicitar callback
  static Future<bool> requestCallback({
    required int userId,
    required String phone,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/request_callback.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usuario_id': userId,
          'telefono': phone,
          'motivo': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error solicitando callback: $e');
      return false;
    }
  }
}

import 'dart:convert';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/network/network_request_executor.dart';

DateTime _parseSupportDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return DateTime.now();

  final hasTimezone = RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$').hasMatch(raw);
  final normalized = hasTimezone ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(normalized) ?? DateTime.now();
}

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
  final int? usuarioId;
  final String? usuarioNombre;
  final String? usuarioApellido;
  final String? usuarioEmail;
  final int? agenteId;
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
    this.usuarioId,
    this.usuarioNombre,
    this.usuarioApellido,
    this.usuarioEmail,
    this.agenteId,
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
      usuarioId: json['usuario_id'],
      usuarioNombre: json['usuario_nombre']?.toString(),
      usuarioApellido: json['usuario_apellido']?.toString(),
      usuarioEmail: json['usuario_email']?.toString(),
      agenteId: json['agente_id'],
      createdAt: _parseSupportDate(json['created_at']),
      updatedAt: _parseSupportDate(json['updated_at']),
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
      createdAt: _parseSupportDate(json['created_at']),
    );
  }
}

class TicketLogEntry {
  final int id;
  final String accion;
  final String? actorNombre;
  final String? actorApellido;
  final DateTime createdAt;

  TicketLogEntry({
    required this.id,
    required this.accion,
    this.actorNombre,
    this.actorApellido,
    required this.createdAt,
  });

  factory TicketLogEntry.fromJson(Map<String, dynamic> json) {
    return TicketLogEntry(
      id: json['id'] ?? 0,
      accion: json['accion']?.toString() ?? 'Actualizacion',
      actorNombre: json['actor_nombre']?.toString(),
      actorApellido: json['actor_apellido']?.toString(),
      createdAt: _parseSupportDate(json['created_at']),
    );
  }
}

/// Servicio de soporte
class SupportService {
  static final String _baseUrl = '${AppConfig.baseUrl}/support';
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  /// Obtener categorías de soporte
  static Future<List<SupportCategory>> getCategories() async {
    try {
      final result = await _network.getJson(
        url: Uri.parse('$_baseUrl/get_categories.php'),
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return [];
      }

      final data = result.json!;
      if (data['success'] == true) {
        final List<dynamic> categorias = data['categorias'] ?? [];
        return categorias.map((c) => SupportCategory.fromJson(c)).toList();
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
      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/create_ticket.php'),
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
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return null;
      }

      final data = result.json!;
      if (data['success'] == true) {
        return data['ticket'];
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

      final result = await _network.getJson(
        url: uri,
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return [];
      }

      final data = result.json!;
      if (data['success'] == true) {
        final List<dynamic> tickets = data['tickets'] ?? [];
        return tickets.map((t) => SupportTicket.fromJson(t)).toList();
      }

      return [];
    } catch (e) {
      print('Error obteniendo tickets: $e');
      return [];
    }
  }

  /// Obtener tickets en modo operativo de agente/admin
  static Future<List<SupportTicket>> getOperationalTickets({
    required int agentId,
    String? status,
    String? priority,
    String? assignedTo,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'agente_id': agentId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['estado'] = status;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['prioridad'] = priority;
      }
      if (assignedTo != null && assignedTo.isNotEmpty) {
        queryParams['asignado_a'] = assignedTo;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$_baseUrl/get_tickets.php')
          .replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: uri,
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return [];
      }

      final data = result.json!;
      if (data['success'] == true) {
        final List<dynamic> tickets = data['tickets'] ?? [];
        return tickets.map((t) => SupportTicket.fromJson(t)).toList();
      }

      return [];
    } catch (e) {
      print('Error obteniendo tickets operativos: $e');
      return [];
    }
  }

  /// Obtener mensajes de un ticket
  static Future<Map<String, dynamic>?> getTicketMessages({
    required int ticketId,
    int? userId,
    int? agentId,
  }) async {
    try {
      final queryParams = {
        'ticket_id': ticketId.toString(),
      };
      if (userId != null) {
        queryParams['usuario_id'] = userId.toString();
      }
      if (agentId != null) {
        queryParams['agente_id'] = agentId.toString();
      }

      final uri = Uri.parse('$_baseUrl/get_ticket_messages.php')
          .replace(queryParameters: queryParams);

      final result = await _network.getJson(
        url: uri,
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return null;
      }

      final data = result.json!;
      if (data['success'] == true) {
        final List<dynamic> mensajes = data['mensajes'] ?? [];
        return {
          'ticket': data['ticket'],
          'mensajes': mensajes.map((m) => TicketMessage.fromJson(m)).toList(),
        };
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
    int? userId,
    int? agentId,
    required String message,
  }) async {
    try {
      final payload = {
        'ticket_id': ticketId,
        'mensaje': message,
      };
      if (userId != null) {
        payload['usuario_id'] = userId;
      }
      if (agentId != null) {
        payload['agente_id'] = agentId;
      }

      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/send_message.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return null;
      }

      final data = result.json!;
      if (data['success'] == true && data['mensaje'] != null) {
        return TicketMessage.fromJson(data['mensaje']);
      }

      return null;
    } catch (e) {
      print('Error enviando mensaje: $e');
      return null;
    }
  }

  static Future<bool> updateTicket({
    required int ticketId,
    required int agentId,
    String? status,
    String? priority,
    String? assignedTo,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'ticket_id': ticketId,
        'agente_id': agentId,
      };
      if (status != null && status.isNotEmpty) {
        payload['estado'] = status;
      }
      if (priority != null && priority.isNotEmpty) {
        payload['prioridad'] = priority;
      }
      if (assignedTo != null) {
        payload['asignado_a'] = assignedTo;
      }

      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/update_ticket.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return false;
      }

      return result.json!['success'] == true;
    } catch (e) {
      print('Error actualizando ticket: $e');
      return false;
    }
  }

  static Future<List<TicketLogEntry>> getTicketLogs({
    required int ticketId,
    required int agentId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/get_ticket_logs.php').replace(
        queryParameters: {
          'ticket_id': ticketId.toString(),
          'agente_id': agentId.toString(),
        },
      );

      final result = await _network.getJson(
        url: uri,
        headers: {'Accept': 'application/json'},
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return [];
      }

      final data = result.json!;
      if (data['success'] == true) {
        final List<dynamic> logs = data['logs'] ?? [];
        return logs.map((item) => TicketLogEntry.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      print('Error obteniendo historial del ticket: $e');
      return [];
    }
  }

  /// Solicitar callback
  static Future<bool> requestCallback({
    required int userId,
    required String phone,
    String? reason,
  }) async {
    try {
      final result = await _network.postJson(
        url: Uri.parse('$_baseUrl/request_callback.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usuario_id': userId,
          'telefono': phone,
          'motivo': reason,
        }),
        timeout: AppConfig.connectionTimeout,
      );

      if (!result.success || result.json == null) {
        return false;
      }

      final data = result.json!;
      return data['success'] == true;
    } catch (e) {
      print('Error solicitando callback: $e');
      return false;
    }
  }
}

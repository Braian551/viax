import 'package:flutter/material.dart';

/// Modelo de notificación del usuario
/// Representa una notificación individual con toda su información
class NotificationModel {
  final int id;
  final String titulo;
  final String mensaje;
  final bool leida;
  final DateTime? leidaEn;
  final String? referenciaTipo;
  final int? referenciaId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String tipo;
  final String tipoNombre;
  final String tipoIcono;
  final String tipoColor;

  NotificationModel({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    this.leidaEn,
    this.referenciaTipo,
    this.referenciaId,
    required this.data,
    required this.createdAt,
    required this.tipo,
    required this.tipoNombre,
    required this.tipoIcono,
    required this.tipoColor,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      titulo: json['titulo'] ?? '',
      mensaje: json['mensaje'] ?? '',
      leida: json['leida'] ?? false,
      leidaEn: json['leida_en'] != null 
          ? DateTime.tryParse(json['leida_en']) 
          : null,
      referenciaTipo: json['referencia_tipo'],
      referenciaId: json['referencia_id'],
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      tipo: json['tipo'] ?? 'system',
      tipoNombre: json['tipo_nombre'] ?? 'Sistema',
      tipoIcono: json['tipo_icono'] ?? 'notifications',
      tipoColor: json['tipo_color'] ?? '#2196F3',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'mensaje': mensaje,
      'leida': leida,
      'leida_en': leidaEn?.toIso8601String(),
      'referencia_tipo': referenciaTipo,
      'referencia_id': referenciaId,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'tipo': tipo,
      'tipo_nombre': tipoNombre,
      'tipo_icono': tipoIcono,
      'tipo_color': tipoColor,
    };
  }

  /// Obtiene el icono de Material Icons correspondiente
  IconData get icon {
    switch (tipoIcono) {
      case 'directions_car':
        return Icons.directions_car;
      case 'cancel':
        return Icons.cancel;
      case 'check_circle':
        return Icons.check_circle;
      case 'near_me':
        return Icons.near_me;
      case 'access_time':
        return Icons.access_time;
      case 'payment':
        return Icons.payment;
      case 'pending':
        return Icons.pending;
      case 'local_offer':
        return Icons.local_offer;
      case 'info':
        return Icons.info;
      case 'star':
        return Icons.star;
      case 'chat':
        return Icons.chat;
      case 'gavel':
        return Icons.gavel;
      default:
        return Icons.notifications;
    }
  }

  /// Obtiene el color como Color de Flutter
  Color get color {
    try {
      final hexColor = tipoColor.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  /// Tiempo relativo desde que se creó
  String get tiempoRelativo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Copia con modificaciones
  NotificationModel copyWith({
    int? id,
    String? titulo,
    String? mensaje,
    bool? leida,
    DateTime? leidaEn,
    String? referenciaTipo,
    int? referenciaId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    String? tipo,
    String? tipoNombre,
    String? tipoIcono,
    String? tipoColor,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      leida: leida ?? this.leida,
      leidaEn: leidaEn ?? this.leidaEn,
      referenciaTipo: referenciaTipo ?? this.referenciaTipo,
      referenciaId: referenciaId ?? this.referenciaId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      tipo: tipo ?? this.tipo,
      tipoNombre: tipoNombre ?? this.tipoNombre,
      tipoIcono: tipoIcono ?? this.tipoIcono,
      tipoColor: tipoColor ?? this.tipoColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Modelo de configuración de notificaciones
class NotificationSettings {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final bool notifViajes;
  final bool notifPagos;
  final bool notifPromociones;
  final bool notifSistema;
  final bool notifChat;
  final String? horarioSilenciosoInicio;
  final String? horarioSilenciosoFin;

  NotificationSettings({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.notifViajes = true,
    this.notifPagos = true,
    this.notifPromociones = true,
    this.notifSistema = true,
    this.notifChat = true,
    this.horarioSilenciosoInicio,
    this.horarioSilenciosoFin,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['push_enabled'] ?? true,
      emailEnabled: json['email_enabled'] ?? true,
      smsEnabled: json['sms_enabled'] ?? false,
      notifViajes: json['notif_viajes'] ?? true,
      notifPagos: json['notif_pagos'] ?? true,
      notifPromociones: json['notif_promociones'] ?? true,
      notifSistema: json['notif_sistema'] ?? true,
      notifChat: json['notif_chat'] ?? true,
      horarioSilenciosoInicio: json['horario_silencioso_inicio'],
      horarioSilenciosoFin: json['horario_silencioso_fin'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'sms_enabled': smsEnabled,
      'notif_viajes': notifViajes,
      'notif_pagos': notifPagos,
      'notif_promociones': notifPromociones,
      'notif_sistema': notifSistema,
      'notif_chat': notifChat,
      'horario_silencioso_inicio': horarioSilenciosoInicio,
      'horario_silencioso_fin': horarioSilenciosoFin,
    };
  }

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? notifViajes,
    bool? notifPagos,
    bool? notifPromociones,
    bool? notifSistema,
    bool? notifChat,
    String? horarioSilenciosoInicio,
    String? horarioSilenciosoFin,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      notifViajes: notifViajes ?? this.notifViajes,
      notifPagos: notifPagos ?? this.notifPagos,
      notifPromociones: notifPromociones ?? this.notifPromociones,
      notifSistema: notifSistema ?? this.notifSistema,
      notifChat: notifChat ?? this.notifChat,
      horarioSilenciosoInicio: horarioSilenciosoInicio ?? this.horarioSilenciosoInicio,
      horarioSilenciosoFin: horarioSilenciosoFin ?? this.horarioSilenciosoFin,
    );
  }
}

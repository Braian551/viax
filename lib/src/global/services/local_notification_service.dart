import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio para mostrar notificaciones locales del dispositivo.
///
/// Usado para alertar al usuario sobre nuevos mensajes de chat
/// incluso cuando la app está en segundo plano.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Stream para manejar clics en notificaciones
  static final StreamController<String?> _onNotificationClick =
      StreamController<String?>.broadcast();

  static Stream<String?> get onNotificationClick => _onNotificationClick.stream;

  static bool _isInitialized = false;

  /// Inicializa el servicio de notificaciones.
  /// Debe llamarse al iniciar la app (en main.dart).
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Crear canal de notificaciones para mensajes
    await _createMessageChannel();

    _isInitialized = true;
    debugPrint('🔔 [LocalNotificationService] Inicializado');
  }

  /// Crea el canal de notificaciones para mensajes de chat.
  static Future<void> _createMessageChannel() async {
    const channel = AndroidNotificationChannel(
      'chat_messages',
      'Mensajes de Chat',
      description: 'Notificaciones de nuevos mensajes durante viajes',
      importance: Importance.high,
      playSound: true,
      // Usa el sonido por defecto del sistema
      // Para sonido personalizado, necesitas configurar en Android nativo
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Muestra una notificación de nuevo mensaje.
  static Future<void> showMessageNotification({
    required String title,
    required String body,
    int? solicitudId,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ [LocalNotificationService] No inicializado');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Mensajes de Chat',
      channelDescription: 'Notificaciones de nuevos mensajes durante viajes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
      // Vibración
      enableVibration: true,
      // Sonido (usa el del canal)
      playSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // Usar solicitudId como ID de notificación para agrupar por viaje
    final notificationId = solicitudId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: solicitudId?.toString(),
    );

    debugPrint('🔔 [LocalNotificationService] Notificación mostrada: $title');
  }

  /// Callback cuando el usuario toca la notificación.
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 [LocalNotificationService] Notificación tocada: ${response.payload}');
    _onNotificationClick.add(response.payload);
  }

  /// Cancela todas las notificaciones activas.
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancela notificaciones de un viaje específico.
  static Future<void> cancelForTrip(int solicitudId) async {
    await _notifications.cancel(solicitudId);
  }

  /// Solicitar permisos de notificación (Android 13+)
  static Future<bool> requestPermission() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidImplementation?.requestNotificationsPermission();
    return granted ?? false;
  }
}

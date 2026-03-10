import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../firebase_options.dart';
import '../../../global/services/auth/user_service.dart';
import '../../../global/services/local_notification_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final title = _resolveNotificationTitle(message);
  final body = _resolveNotificationBody(message);

  // Para mensajes con payload "notification", Android suele mostrarlos
  // automáticamente en background/terminada. Solo forzamos local cuando
  // viene data-only para asegurar entrega fuera de la app.
  if (message.notification != null) {
    return;
  }

  if ((title ?? '').isEmpty && (body ?? '').isEmpty) {
    return;
  }

  await LocalNotificationService.initialize();
  await LocalNotificationService.showNotification(
    title: title ?? 'Nueva notificación',
    body: body ?? '',
    payload: _resolveNotificationPayload(message),
    channelId: _resolveChannelId(message),
    channelName: _resolveChannelName(message),
    channelDescription: _resolveChannelDescription(message),
    notificationId: _resolveNotificationId(message),
  );
}

String? _resolveNotificationTitle(RemoteMessage message) {
  return message.notification?.title ??
      message.data['title']?.toString() ??
      message.data['notification_title']?.toString();
}

String? _resolveNotificationBody(RemoteMessage message) {
  return message.notification?.body ??
      message.data['body']?.toString() ??
      message.data['message']?.toString() ??
      message.data['notification_body']?.toString();
}

String _resolveNotificationPayload(RemoteMessage message) {
  final solicitudId = message.data['solicitud_id']?.toString() ??
      message.data['trip_id']?.toString() ??
      message.data['request_id']?.toString();

  if (solicitudId != null && solicitudId.isNotEmpty) {
    return solicitudId;
  }

  return jsonEncode(message.data);
}

int _resolveNotificationId(RemoteMessage message) {
  final messageIdNum = int.tryParse(message.messageId ?? '');
  if (messageIdNum != null) return messageIdNum;

  final dataMessageId = int.tryParse(message.data['message_id']?.toString() ?? '');
  if (dataMessageId != null) return dataMessageId;

  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

String _resolveChannelId(RemoteMessage message) {
  final type = message.data['type']?.toString().toLowerCase();
  if (type == 'chat' || message.data.containsKey('solicitud_id')) {
    return 'chat_messages';
  }
  return 'viax_events';
}

String _resolveChannelName(RemoteMessage message) {
  final channelId = _resolveChannelId(message);
  if (channelId == 'chat_messages') {
    return 'Mensajes de Chat';
  }
  return 'Eventos Viax';
}

String _resolveChannelDescription(RemoteMessage message) {
  final channelId = _resolveChannelId(message);
  if (channelId == 'chat_messages') {
    return 'Notificaciones de nuevos mensajes durante viajes';
  }
  return 'Eventos de viajes, pagos y documentos';
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final StreamController<RemoteMessage> _onMessageController =
      StreamController<RemoteMessage>.broadcast();
  static final StreamController<RemoteMessage> _onNotificationTapController =
      StreamController<RemoteMessage>.broadcast();

  static bool _initialized = false;
  static int? _currentUserId;
  static bool _isSyncingToken = false;
  static Timer? _retryTimer;
  static String? _lastRegisteredToken;
  static int? _lastRegisteredUserId;

  static Stream<RemoteMessage> get onMessage => _onMessageController.stream;
  static Stream<RemoteMessage> get onNotificationTap =>
      _onNotificationTapController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setAutoInitEnabled(true);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      _onMessageController.add(message);

      final title = _resolveNotificationTitle(message);
      final body = _resolveNotificationBody(message);

      if ((title ?? '').isNotEmpty || (body ?? '').isNotEmpty) {
        await LocalNotificationService.showNotification(
          title: title ?? 'Nueva notificación',
          body: body ?? '',
          payload: _resolveNotificationPayload(message),
          channelId: _resolveChannelId(message),
          channelName: _resolveChannelName(message),
          channelDescription: _resolveChannelDescription(message),
          notificationId: _resolveNotificationId(message),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onMessageController.add(message);
      _onNotificationTapController.add(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onMessageController.add(initialMessage);
        _onNotificationTapController.add(initialMessage);
      });
    }

    _messaging.onTokenRefresh.listen((token) async {
      final userId = _currentUserId;
      if (userId != null && userId > 0) {
        await _registerTokenWithRetry(userId: userId, token: token);
      }
    });

    _initialized = true;
  }

  static Future<void> syncForCurrentSession() async {
    final session = await UserService.getSavedSession();
    final rawUserId = session?['id'];
    final userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');

    if (userId == null || userId <= 0) {
      return;
    }

    await registerCurrentDeviceForUser(userId);
  }

  static Future<void> registerCurrentDeviceForUser(int userId) async {
    _currentUserId = userId;

    if (_isSyncingToken) {
      return;
    }

    _isSyncingToken = true;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [PushNotificationService] No se pudo obtener token FCM');
        _scheduleRetry(userId);
        return;
      }

      await _registerTokenWithRetry(userId: userId, token: token);
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] Error obteniendo token FCM: $e');
      _scheduleRetry(userId);
    } finally {
      _isSyncingToken = false;
    }
  }

  static Future<void> _registerTokenWithRetry({
    required int userId,
    required String token,
  }) async {
    if (_lastRegisteredUserId == userId && _lastRegisteredToken == token) {
      return;
    }

    Map<String, dynamic>? lastResult;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final result = await NotificationService.registerPushToken(
        userId: userId,
        token: token,
        plataforma: _platformName(),
        deviceName: 'Flutter App',
      );

      if (result['success'] == true) {
        _lastRegisteredUserId = userId;
        _lastRegisteredToken = token;
        _retryTimer?.cancel();
        _retryTimer = null;
        debugPrint('✅ [PushNotificationService] Token push sincronizado correctamente');
        return;
      }

      lastResult = result;
      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }

    final error = lastResult?['error']?.toString() ?? 'Error desconocido';
    final errorType = lastResult?['error_type']?.toString() ?? 'unknown';
    debugPrint(
      '⚠️ [PushNotificationService] No se pudo registrar token push '
      '(tipo=$errorType): $error',
    );
    _scheduleRetry(userId);
  }

  static void _scheduleRetry(int userId) {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 20), () {
      registerCurrentDeviceForUser(userId);
    });
  }

  static Future<void> unregisterCurrentDevice({int? userId}) async {
    _retryTimer?.cancel();
    _retryTimer = null;

    final token = await _messaging.getToken();
    final resolvedUserId = userId ?? _currentUserId;

    if (resolvedUserId == null || resolvedUserId <= 0 || token == null) {
      return;
    }

    await NotificationService.unregisterPushToken(
      userId: resolvedUserId,
      token: token,
    );

    if (_lastRegisteredUserId == resolvedUserId && _lastRegisteredToken == token) {
      _lastRegisteredUserId = null;
      _lastRegisteredToken = null;
    }
  }

  static String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'android';
    }
  }
}

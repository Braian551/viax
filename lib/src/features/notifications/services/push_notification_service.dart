import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../../firebase_options.dart';
import '../../../global/services/auth/user_service.dart';
import '../../../global/services/local_notification_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final StreamController<RemoteMessage> _onMessageController =
      StreamController<RemoteMessage>.broadcast();

  static bool _initialized = false;
  static int? _currentUserId;

  static Stream<RemoteMessage> get onMessage => _onMessageController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      _onMessageController.add(message);

      final title = message.notification?.title ?? message.data['title'];
      final body = message.notification?.body ?? message.data['body'];

      if ((title ?? '').isNotEmpty || (body ?? '').isNotEmpty) {
        await LocalNotificationService.showNotification(
          title: title?.toString() ?? 'Nueva notificación',
          body: body?.toString() ?? '',
          payload: jsonEncode(message.data),
          channelId: 'viax_events',
          channelName: 'Eventos Viax',
          channelDescription: 'Eventos de viajes, pagos y documentos',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onMessageController.add(message);
    });

    _messaging.onTokenRefresh.listen((token) async {
      final userId = _currentUserId;
      if (userId != null && userId > 0) {
        await NotificationService.registerPushToken(
          userId: userId,
          token: token,
        );
      }
    });

    _initialized = true;
  }

  static Future<void> syncForCurrentSession() async {
    final session = await UserService.getSavedSession();
    final userId = session?['id'] as int?;

    if (userId == null || userId <= 0) {
      return;
    }

    await registerCurrentDeviceForUser(userId);
  }

  static Future<void> registerCurrentDeviceForUser(int userId) async {
    _currentUserId = userId;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ [PushNotificationService] No se pudo obtener token FCM');
      return;
    }

    final result = await NotificationService.registerPushToken(
      userId: userId,
      token: token,
      plataforma: _platformName(),
      deviceName: 'Flutter App',
    );

    if (result['success'] != true) {
      debugPrint('⚠️ [PushNotificationService] No se pudo registrar token push: ${result['error']}');
    }
  }

  static Future<void> unregisterCurrentDevice({int? userId}) async {
    final token = await _messaging.getToken();
    final resolvedUserId = userId ?? _currentUserId;

    if (resolvedUserId == null || resolvedUserId <= 0 || token == null) {
      return;
    }

    await NotificationService.unregisterPushToken(
      userId: resolvedUserId,
      token: token,
    );
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

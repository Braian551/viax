import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
// ignore: depend_on_referenced_packages
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:viax/firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/routes/app_router.dart';
import 'package:viax/src/providers/database_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_profile_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_trips_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_earnings_provider.dart';
import 'package:viax/src/features/legal/providers/legal_provider.dart';
import 'package:viax/src/core/di/service_locator.dart';
import 'package:viax/src/global/services/app_secrets_service.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:viax/src/theme/theme_provider.dart';
import 'package:viax/src/global/services/local_notification_service.dart';
import 'package:viax/src/features/notifications/services/push_notification_service.dart';
import 'package:viax/src/global/widgets/floating_trip_fab.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:viax/src/global/services/active_trip_navigation_service.dart';
import 'package:viax/src/core/network/connectivity_service.dart';
import 'package:viax/src/core/network/network_status_service.dart';
import 'package:viax/src/core/network/widgets/global_connectivity_banner.dart';
import 'package:viax/src/core/offline/trip_command_queue.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:app_links/app_links.dart';
import 'package:viax/src/features/location_sharing/services/location_sharing_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/map_preload_service.dart';

void main() async {
  runZonedGuarded(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: binding);

      // Configurar el manejo global de errores lo antes posible.

      // Bloquear la app en orientación vertical para evitar rotación automática.
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);

      // Enviar errores del framework Flutter al manejador de la zona.
      FlutterError.onError = (FlutterErrorDetails details) {
        try {
          developer.log(
            'FlutterError: \n${details.exceptionAsString()}\n${details.stack}',
            name: 'GlobalError',
          );
        } catch (_) {}
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.current,
        );
      };

      // Capturar errores asíncronos y de canales de plataforma.
      ui.PlatformDispatcher.instance.onError =
          (Object error, StackTrace stack) {
            try {
              developer.log(
                'PlatformDispatcher error: $error',
                name: 'GlobalError',
                stackTrace: stack,
              );
            } catch (_) {}
            return true;
          };

      // Mostrar un error amable si falla la construcción de la interfaz.
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Material(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFF2196F3),
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Se produjo un error en la interfaz',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      };

      // FASE 1: solo inicialización crítica antes de runApp().
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase inicializado correctamente');
      } catch (e) {
        debugPrint('⚠️ Error inicializando Firebase: $e');
      }

      runApp(ViaxAppRoot(serviceLocator: ServiceLocator()));
    },
    (Object error, StackTrace stack) {
      try {
        developer.log(
          'Uncaught (zoned): $error',
          name: 'GlobalError',
          stackTrace: stack,
        );
      } catch (_) {}
    },
  );
}

class ViaxAppRoot extends StatefulWidget {
  final ServiceLocator serviceLocator;

  const ViaxAppRoot({super.key, required this.serviceLocator});

  @override
  State<ViaxAppRoot> createState() => _ViaxAppRootState();
}

class _ViaxAppRootState extends State<ViaxAppRoot> {
  bool _microserviceProvidersReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBackgroundServices();
    });
  }

  Future<void> _initializeBackgroundServices() async {
    final sw = Stopwatch()..start();
    debugPrint('⏱️ [Startup] INICIO inicialización background');
    // FASE 2: inicializaciones independientes después de pintar la primera UI.
    await Future.wait<void>([
      _initializeAppSecrets(),
      _initializeDateFormatters(),
      _initializeLocalNotifications(),
      _initializeConnectivity(),
      _initializeTripCommandQueue(),
      _initializeNetworkStatus(),
      _initializeServiceLocator(),
    ]);

    if (mounted && widget.serviceLocator.isInitialized) {
      setState(() => _microserviceProvidersReady = true);
    }

    FlutterNativeSplash.remove();

    // FASE 3: servicios que dependen de resultados de la fase 2.
    await _initializeDependentServices();

    debugPrint('⏱️ [Startup] FIN total: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializeAppSecrets() async {
    final sw = Stopwatch()..start();
    try {
      final secretsLoaded = await AppSecretsService.instance.initialize();
      if (secretsLoaded) {
        debugPrint('✅ API Keys disponibles');
      } else {
        debugPrint('⚠️ API Keys no disponibles en este arranque');
      }
      debugPrint(
        '   - Mapbox Token: ${AppSecretsService.instance.mapboxToken.isNotEmpty ? "✓" : "✗"}',
      );
      debugPrint(
        '   - Google Places API: ${AppSecretsService.instance.googlePlacesApiKey.isNotEmpty ? "✓" : "✗"}',
      );
    } catch (e) {
      debugPrint('⚠️ Error cargando API Keys: $e');
    }

    debugPrint('⏱️ [Startup] AppSecretsService: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializeDateFormatters() async {
    final sw = Stopwatch()..start();
    try {
      await initializeDateFormatting('es_CO', null);
      debugPrint('✅ Formatos de fecha inicializados');
    } catch (e) {
      debugPrint('⚠️ Error inicializando formatos de fecha: $e');
    }

    debugPrint('⏱️ [Startup] DateFormatters: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializeLocalNotifications() async {
    final sw = Stopwatch()..start();
    try {
      await LocalNotificationService.initialize();
      unawaited(
        LocalNotificationService.requestPermission().catchError((Object error) {
          debugPrint(
            '⚠️ Error solicitando permisos notificaciones: $error',
          );
          return false;
        }),
      );
      debugPrint(
        '✅ Notificaciones locales inicializadas y permisos en segundo plano',
      );
    } catch (e) {
      debugPrint('⚠️ Error inicializando notificaciones locales: $e');
    }

    debugPrint(
      '⏱️ [Startup] LocalNotificationService: ${sw.elapsedMilliseconds}ms',
    );
  }

  Future<void> _initializeConnectivity() async {
    final sw = Stopwatch()..start();
    try {
      await ConnectivityService().initialize();
      debugPrint('✅ ConnectivityService inicializado');
    } catch (e) {
      debugPrint('⚠️ Error inicializando ConnectivityService: $e');
    }

    debugPrint('⏱️ [Startup] ConnectivityService: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializeTripCommandQueue() async {
    final sw = Stopwatch()..start();
    try {
      await TripCommandQueue.instance.initialize();
      debugPrint('✅ TripCommandQueue inicializado');
    } catch (e) {
      debugPrint('⚠️ Error inicializando TripCommandQueue: $e');
    }

    debugPrint('⏱️ [Startup] TripCommandQueue: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializeNetworkStatus() async {
    final sw = Stopwatch()..start();
    try {
      await NetworkStatusService.instance.initialize();
      debugPrint('✅ NetworkStatusService inicializado');
    } catch (e) {
      debugPrint('⚠️ Error inicializando NetworkStatusService: $e');
    }

    debugPrint(
      '⏱️ [Startup] NetworkStatusService: ${sw.elapsedMilliseconds}ms',
    );
  }

  Future<void> _initializeServiceLocator() async {
    final sw = Stopwatch()..start();
    try {
      await widget.serviceLocator.init();
      debugPrint('✅ ServiceLocator inicializado');
    } catch (e, stack) {
      developer.log(
        'Error inicializando ServiceLocator',
        name: 'Startup',
        error: e,
        stackTrace: stack,
      );
    }

    debugPrint('⏱️ [Startup] ServiceLocator: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializeDependentServices() async {
    final sw = Stopwatch()..start();
    _initializeMapboxToken();

    await Future.wait<void>([
      _initializeMapPreload(),
      _initializePushNotifications(),
    ]);

    debugPrint(
      '⏱️ [Startup] Servicios dependientes: ${sw.elapsedMilliseconds}ms',
    );
  }

  void _initializeMapboxToken() {
    final sw = Stopwatch()..start();
    try {
      final mapboxToken = AppSecretsService.instance.mapboxToken;
      if (mapboxToken.isNotEmpty) {
        MapboxOptions.setAccessToken(mapboxToken);
        debugPrint('✅ Mapbox inicializado correctamente');
      } else {
        debugPrint('⚠️ Mapbox token no disponible');
      }
    } catch (e) {
      debugPrint('⚠️ Error inicializando Mapbox: $e');
    }

    debugPrint('⏱️ [Startup] MapboxToken: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializeMapPreload() async {
    final sw = Stopwatch()..start();
    try {
      await MapPreloadService.preload();
      debugPrint('✅ Map preload listo');
    } catch (e) {
      debugPrint('⚠️ Error en map preload: $e');
    }

    debugPrint('⏱️ [Startup] MapPreload: ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initializePushNotifications() async {
    final sw = Stopwatch()..start();
    try {
      await PushNotificationService.initialize();
      unawaited(
        PushNotificationService.syncForCurrentSession().catchError((Object e) {
          debugPrint('⚠️ Error sincronizando push: $e');
        }),
      );
      debugPrint('✅ Push notifications (FCM) inicializadas');
    } catch (e) {
      debugPrint('⚠️ Error inicializando push notifications: $e');
    }

    debugPrint(
      '⏱️ [Startup] PushNotificationService: ${sw.elapsedMilliseconds}ms',
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceLocatorReady =
        _microserviceProvidersReady && widget.serviceLocator.isInitialized;

    return MultiProvider(
      providers: [
        // Provider de tema (debe estar primero).
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // Provider legal (anti-bypass).
        ChangeNotifierProvider(create: (_) => LegalProvider()..init()),

        // Provider de base de datos (legacy).
        ChangeNotifierProvider(create: (_) => DatabaseProvider()),

        // Providers legacy de conductor.
        ChangeNotifierProvider(create: (_) => ConductorProvider()),
        ChangeNotifierProvider(create: (_) => ConductorProfileProvider()),
        ChangeNotifierProvider(create: (_) => ConductorTripsProvider()),
        ChangeNotifierProvider(create: (_) => ConductorEarningsProvider()),

        // Provider del microservicio de usuario.
        if (serviceLocatorReady)
          ChangeNotifierProvider(
            create: (_) => widget.serviceLocator.createUserProvider(),
          ),

        // Provider del microservicio de conductor.
        if (serviceLocatorReady)
          ChangeNotifierProvider(
            create: (_) =>
                widget.serviceLocator.createConductorProfileProvider(),
          ),

        // Provider del microservicio de viajes.
        if (serviceLocatorReady)
          ChangeNotifierProvider(
            create: (_) => widget.serviceLocator.createTripProvider(),
          ),

        // Provider del microservicio de mapas.
        if (serviceLocatorReady)
          ChangeNotifierProvider(
            create: (_) => widget.serviceLocator.createMapProvider(),
          ),

        // Provider del microservicio de administración.
        if (serviceLocatorReady)
          ChangeNotifierProvider(
            create: (_) => widget.serviceLocator.createAdminProvider(),
          ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  final bool enableDatabaseInit;

  const MyApp({super.key, this.enableDatabaseInit = true});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<Uri>? _deepLinkSub;
  StreamSubscription<String?>? _localNotificationTapSub;
  StreamSubscription<RemoteMessage>? _pushNotificationTapSub;
  bool _databaseInitTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _initNotificationRedirects();
    _initDatabaseInBackgroundOnce();
  }

  void _initDatabaseInBackgroundOnce() {
    if (!widget.enableDatabaseInit || _databaseInitTriggered) {
      return;
    }
    _databaseInitTriggered = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final databaseProvider = context.read<DatabaseProvider>();
      Future.microtask(() async {
        try {
          await databaseProvider.initializeDatabase();
        } catch (e) {
          debugPrint('⚠️ Error inicializando base de datos: $e');
        }
      });
    });
  }

  void _initNotificationRedirects() {
    _localNotificationTapSub = LocalNotificationService.onNotificationClick
        .listen((payload) {
          _handleNotificationOpen(payload: payload);
        });

    _pushNotificationTapSub = PushNotificationService.onNotificationTap.listen((
      message,
    ) {
      _handleNotificationOpen(data: message.data);
    });
  }

  Future<void> _handleNotificationOpen({
    Map<String, dynamic>? data,
    String? payload,
  }) async {
    final session = await UserService.getSavedSession();
    final userId = int.tryParse(session?['id']?.toString() ?? '') ?? 0;
    if (userId <= 0) return;

    final userType = (session?['tipo_usuario'] ?? '').toString().toLowerCase();

    // Si viene referencia explícita de pagos empresa/admin, redirigir a su módulo.
    final referenceType =
        (data?['reference_type'] ?? data?['referencia_tipo'] ?? '')
            .toString()
            .toLowerCase();
    final tipo = (data?['tipo'] ?? '').toString().toLowerCase();

    if ((userType == 'admin' || userType == 'administrador') &&
        (referenceType == 'pago_empresa_reporte' ||
            referenceType == 'factura' ||
            tipo.startsWith('empresa_payment_') ||
            tipo == 'invoice_generated')) {
      ActiveTripNavigationService.navigatorKey.currentState?.pushNamed(
        RouteNames.adminCompanyPaymentReports,
        arguments: {'admin_id': userId, 'admin_user': session},
      );
      return;
    }

    // Fallback universal: abrir bandeja de notificaciones con contexto del usuario.
    ActiveTripNavigationService.navigatorKey.currentState?.pushNamed(
      RouteNames.notifications,
      arguments: {
        'userId': userId,
        'currentUser': session,
        'userType': userType,
        if (payload != null) 'payload': payload,
      },
    );
  }

  /// Inicializa el manejo de deep links `viax://share/{token}`.
  void _initDeepLinks() {
    final appLinks = AppLinks();

    // Manejar el enlace que abrió la app desde un arranque en frío.
    appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) _handleDeepLink(uri);
        })
        .catchError((_) {});

    // Manejar enlaces mientras la app está en ejecución.
    _deepLinkSub = appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) => debugPrint('[DeepLink] Error: $e'),
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('[DeepLink] Received: $uri');
    // Formato esperado: viax://share/{token}.
    if (uri.scheme == 'viax' && uri.host == 'share') {
      final token = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : uri.path.replaceFirst('/', '');
      if (token.isNotEmpty) {
        final dismissed = await LocationSharingService.isTokenDismissed(token);
        if (dismissed) {
          debugPrint('[DeepLink] Ignorado (token descartado): $token');
          return;
        }

        final handled = await LocationSharingService.isTokenHandled(token);
        if (handled) {
          debugPrint('[DeepLink] Ignorado (token ya atendido): $token');
          return;
        }

        await LocationSharingService.markTokenHandled(token);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ActiveTripNavigationService.navigatorKey.currentState?.pushNamed(
            RouteNames.sharedLocationView,
            arguments: {'token': token},
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _localNotificationTapSub?.cancel();
    _pushNotificationTapSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final tripNavService = ActiveTripNavigationService();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App va a segundo plano: mostrar overlay del sistema si hay viaje.
        if (tripNavService.hasActiveTrip) {
          tripNavService.showSystemOverlay();
          debugPrint('📱 [App] Pasando a segundo plano - mostrando overlay');
        }
        break;
      case AppLifecycleState.resumed:
        // App vuelve a primer plano: ocultar overlay del sistema siempre.
        tripNavService.hideSystemOverlay();
        Future.microtask(() async {
          await PushNotificationService.syncForCurrentSession();
        });
        debugPrint('📱 [App] Volviendo a primer plano - ocultando overlay');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener el provider de tema.
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      // Llave global para navegación fuera del contexto de widgets.
      navigatorKey: ActiveTripNavigationService.navigatorKey,
      scaffoldMessengerKey: AppConfig.scaffoldMessengerKey,
      title: 'Viax',
      debugShowCheckedModeBanner: false,
      // Usar los temas del ThemeProvider.
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      onGenerateRoute: AppRouter.generateRoute,
      navigatorObservers: [RouteLogger()],
      initialRoute: '/',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      // Agregar el overlay del FAB flotante usando builder.
      builder: (context, child) {
        return GlobalConnectivityBanner(
          child: ActiveTripOverlay(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

// NavigatorObserver simple para registrar cambios de ruta en debug.
class RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    try {
      developer.log(
        'Route pushed: ${route.settings.name} <- from ${previousRoute?.settings.name}',
        name: 'RouteLogger',
      );
    } catch (_) {}
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    try {
      developer.log(
        'Route popped: ${route.settings.name} -> back to ${previousRoute?.settings.name}',
        name: 'RouteLogger',
      );
    } catch (_) {}
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    try {
      developer.log(
        'Route replaced: ${oldRoute?.settings.name} -> ${newRoute?.settings.name}',
        name: 'RouteLogger',
      );
    } catch (_) {}
  }
}

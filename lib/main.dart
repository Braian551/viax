import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui; 
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:viax/firebase_options.dart';
import 'package:viax/src/routes/app_router.dart';   
import 'package:viax/src/providers/database_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_profile_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_trips_provider.dart';
import 'package:viax/src/features/conductor/providers/conductor_earnings_provider.dart';
import 'package:viax/src/core/di/service_locator.dart';
import 'package:viax/src/global/services/app_secrets_service.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:viax/src/theme/theme_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  runZonedGuarded(() async {
    // Configure robust global error handling as early as possible
    WidgetsFlutterBinding.ensureInitialized();

    // NOTE: UI Color Scheme Update (November 2025)
    // - Primary buttons changed from yellow (0xFFFFFF00) to blue (AppColors.primary)
    // - Email auth screens now use consistent blue theming
    // - All buttons maintain white text on blue background for accessibility

    // Forward Flutter framework errors to zone handler (and keep red-screen in debug)
    FlutterError.onError = (FlutterErrorDetails details) {
      // Print to console
      try {
        developer.log(
          'FlutterError: \n${details.exceptionAsString()}\n${details.stack}',
          name: 'GlobalError',
        );
      } catch (_) {}
      // Also forward to the current zone so runZonedGuarded can capture
      Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.current);
    };

    // Catch uncaught async and platform channel errors
    ui.PlatformDispatcher.instance.onError = (Object  error, StackTrace stack) {
      try {
        developer.log('PlatformDispatcher error: $error', name: 'GlobalError', stackTrace: stack);
      } catch (_) {}
      // Return true to indicate the error was handled to avoid process kill
      return true;
    };

    // Friendly error widget in release to avoid hard crash during build failures
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFF2196F3), size: 42),
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

    await initializeDateFormatting('es_ES', null);

    // ============================================
    // INICIALIZAR FIREBASE
    // ============================================
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase inicializado correctamente');
    } catch (e) {
      debugPrint('⚠️ Error inicializando Firebase: $e');
    }

    // ============================================
    // INICIALIZAR API KEYS DESDE BACKEND
    // ============================================
    try {
      await AppSecretsService.instance.initialize();
      debugPrint('✅ API Keys cargadas desde backend');
    } catch (e) {
      debugPrint('⚠️ Error cargando API Keys: $e');
    }

    // ============================================
    // INICIALIZAR MAPBOX CON ACCESS TOKEN
    // ============================================
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

    // Inicializar Service Locator (Inyección de Dependencias)
    // Esto configura todos los datasources, repositories y use cases
    final serviceLocator = ServiceLocator();
    try {
      await serviceLocator.init();
    } catch (e) {
      print('Error initializing service locator: $e');
      // Continue without service locator for now
    }

    runApp(
      MultiProvider(
        providers: [
          // Theme Provider (debe estar primero)
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          
          // Database Provider (legacy)
          ChangeNotifierProvider(create: (_) => DatabaseProvider()),
          
          
          // User Microservice Provider
          if (serviceLocator.isInitialized) ChangeNotifierProvider(
            create: (_) => serviceLocator.createUserProvider(),
          ),
          
          // Conductor Microservice Provider
          if (serviceLocator.isInitialized) ChangeNotifierProvider(
            create: (_) => serviceLocator.createConductorProfileProvider(),
          ),

          // Trip Microservice Provider
          if (serviceLocator.isInitialized) ChangeNotifierProvider(
            create: (_) => serviceLocator.createTripProvider(),
          ),

          // Map Microservice Provider
          if (serviceLocator.isInitialized) ChangeNotifierProvider(
            create: (_) => serviceLocator.createMapProvider(),
          ),

          // Admin Microservice Provider
          if (serviceLocator.isInitialized) ChangeNotifierProvider(
            create: (_) => serviceLocator.createAdminProvider(),
          ),

          // ========== LEGACY PROVIDERS (por deprecar gradualmente) ==========
          
          // Conductor Providers (legacy - funcionalidad migrada a Conductor Microservice)
          ChangeNotifierProvider(create: (_) => ConductorProvider()),
          ChangeNotifierProvider(create: (_) => ConductorProfileProvider()),
          ChangeNotifierProvider(create: (_) => ConductorTripsProvider()),
          ChangeNotifierProvider(create: (_) => ConductorEarningsProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    try {
      developer.log('Uncaught (zoned): $error', name: 'GlobalError', stackTrace: stack);
    } catch (_) {}
  });
}

class MyApp extends StatelessWidget {
  final bool enableDatabaseInit;

  const MyApp({super.key, this.enableDatabaseInit = true});

  @override
  Widget build(BuildContext context) {
    final databaseProvider = Provider.of<DatabaseProvider>(
      context,
      listen: false,
    );
    
    // Obtener el theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Inicializar la base de datos en background cuando se carga la app
    if (enableDatabaseInit) {
      // No bloqueamos la UI: inicializamos en background y dejamos que el RouterScreen se muestre.
      Future.microtask(() async {
        try {
          await databaseProvider.initializeDatabase();
        } catch (e) {
          print('Error initializing database: $e');
          // Continue without crashing the app
        }
      });
    }

    return MaterialApp(
      scaffoldMessengerKey: AppConfig.scaffoldMessengerKey,
      title: 'Viax',
      debugShowCheckedModeBanner: false,
      // Usar los temas del ThemeProvider
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
      supportedLocales: const [
        Locale('es', 'ES'), // Spanish
        Locale('en', 'US'), // English
      ],
    );
  }
}

// Simple NavigatorObserver para loggear cambios de ruta en debug
class RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    try {
      print('Route pushed: ${route.settings.name} <- from ${previousRoute?.settings.name}');
    } catch (_) {}
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    try {
      print('Route popped: ${route.settings.name} -> back to ${previousRoute?.settings.name}');
    } catch (_) {}
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    try {
      print('Route replaced: ${oldRoute?.settings.name} -> ${newRoute?.settings.name}');
    } catch (_) {}
  }
}

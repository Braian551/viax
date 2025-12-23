import 'package:flutter/material.dart';
import 'package:viax/src/features/user/presentation/screens/home_user.dart';
import 'package:viax/src/features/user/presentation/screens/confirm_trip_screen.dart';
import 'package:viax/src/features/user/presentation/screens/enhanced_destination_screen.dart';
import 'package:viax/src/features/user/presentation/screens/user_profile_screen.dart';
import 'package:viax/src/features/user/presentation/screens/payment_methods_screen.dart';
import 'package:viax/src/features/user/presentation/screens/trip_history_screen.dart';
import 'package:viax/src/features/user/presentation/screens/settings_screen.dart';
import 'package:viax/src/features/user/presentation/screens/waiting_for_driver_screen.dart';
import 'package:viax/src/features/user/presentation/screens/user_active_trip_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/login_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/register_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:viax/src/features/onboarding/presentation/screens/onboarding_screen.dart';
// import 'package:viax/src/features/map/presentation/screens/location_selection_screen.dart'; // COMENTADO - YA NO SE USA
import 'package:viax/src/features/map/presentation/screens/location_picker_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/welcome_splash_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/splash_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/users_management_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/statistics_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/audit_logs_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/conductores_documentos_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/pricing_management_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_home_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_profile_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_trips_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_earnings_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_vehicle_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_documents_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_settings_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_help_screen.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/routes/animated_routes.dart';
import 'package:viax/src/widgets/auth_wrapper.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        // initial route used by Navigator(initialRoute: '/')
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.onboarding:
        return FadeSlidePageRoute(page: const OnboardingScreen(), settings: settings);
      case RouteNames.authWrapper:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      case RouteNames.welcome:
        return FadeSlidePageRoute(page: const WelcomeScreen(), settings: settings);
      case RouteNames.login:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return FadeSlidePageRoute(
            page: LoginScreen(
              email: args?['email'],
              prefilled: args?['prefilled'] ?? false,
            ),
            settings: settings,
          );
        }
      case RouteNames.phoneAuth:
        return FadeSlidePageRoute(page: const PhoneAuthScreen(), settings: settings);
      case RouteNames.emailAuth:
        return FadeSlidePageRoute(page: const EmailAuthScreen(), settings: settings);
      case RouteNames.emailVerification:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return FadeSlidePageRoute(
            page: EmailVerificationScreen(
              email: args?['email'] ?? '',
              userName: args?['userName'] ?? '',
            ),
            settings: settings,
          );
        }
      case RouteNames.register:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return FadeSlidePageRoute(
            page: RegisterScreen(
              email: args?['email'] ?? '',
              userName: args?['userName'] ?? '',
            ),
            settings: settings,
          );
        }
      case RouteNames.welcomeSplash:
        return FadeSlidePageRoute(page: const WelcomeSplashScreen(), settings: settings);
      case RouteNames.locationPicker:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => LocationPickerScreen(
              initialAddress: args?['initialAddress'],
              initialLocation: args?['initialLocation'],
              screenTitle: args?['screenTitle'] ?? 'Seleccionar ubicación',
              showConfirmButton: args?['showConfirmButton'] ?? true,
            ),
          );
        }
      case RouteNames.home:
        // Cuando el usuario se autentique debe ir a la pantalla principal (HomeUserScreen)
        return MaterialPageRoute(builder: (_) => const HomeUserScreen());
      
      // Rutas de usuario
      case RouteNames.requestTrip:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return FadeSlidePageRoute(
            page: EnhancedDestinationScreen(
              initialSelection: args?['selecting'],
              preloadedPosition: args?['currentPosition'],
            ),
            settings: settings,
          );
        }
      case RouteNames.confirmTrip:
        return MaterialPageRoute(
          builder: (_) => const ConfirmTripScreen(),
          settings: settings,
        );
      case '/user/waiting_driver':
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => WaitingForDriverScreen(
              solicitudId: args?['solicitud_id'] ?? 0,
              clienteId: args?['cliente_id'] ?? 0,
              direccionOrigen: args?['direccion_origen'] ?? 'Origen',
              direccionDestino: args?['direccion_destino'] ?? 'Destino',
            ),
            settings: settings,
          );
        }
      case '/user/active_trip':
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final origen = args?['origen'] as Map<String, dynamic>?;
          final destino = args?['destino'] as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => UserActiveTripScreen(
              solicitudId: args?['solicitud_id'] ?? 0,
              clienteId: args?['cliente_id'] ?? 0,
              origenLat: (origen?['latitud'] as num?)?.toDouble() ?? 0,
              origenLng: (origen?['longitud'] as num?)?.toDouble() ?? 0,
              direccionOrigen: origen?['direccion'] ?? 'Origen',
              destinoLat: (destino?['latitud'] as num?)?.toDouble() ?? 0,
              destinoLng: (destino?['longitud'] as num?)?.toDouble() ?? 0,
              direccionDestino: destino?['direccion'] ?? 'Destino',
              conductorInfo: args?['conductor'],
            ),
            settings: settings,
          );
        }
      case RouteNames.userProfile:
        return MaterialPageRoute(builder: (_) => const UserProfileScreen());
      case RouteNames.paymentMethods:
        return MaterialPageRoute(builder: (_) => const PaymentMethodsScreen());
      case RouteNames.tripHistory:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['user_id'] ?? args?['id'] ?? 0;
          return MaterialPageRoute(
            builder: (_) => TripHistoryScreen(userId: userId),
          );
        }
      case RouteNames.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case RouteNames.favoritePlaces:
      case RouteNames.promotions:
      case RouteNames.help:
      case RouteNames.about:
      case RouteNames.terms:
      case RouteNames.privacy:
      case RouteNames.editProfile:
      case RouteNames.trackingTrip:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text('Próximamente', style: TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const Center(
              child: Text(
                'Esta función estará disponible pronto',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        );
      
      // Rutas de administrador
      case RouteNames.adminHome:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => AdminHomeScreen(
              adminUser: args?['admin_user'] ?? {},
            ),
          );
        }
      case RouteNames.adminUsers:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => UsersManagementScreen(
              adminId: args?['admin_id'] ?? 0,
              adminUser: args?['admin_user'] ?? {},
            ),
          );
        }
      case RouteNames.adminStatistics:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => StatisticsScreen(
              adminId: args?['admin_id'] ?? 0,
            ),
          );
        }
      case RouteNames.adminAuditLogs:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => AuditLogsScreen(
              adminId: args?['admin_id'] ?? 0,
            ),
          );
        }
      case RouteNames.adminConductorDocs:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ConductoresDocumentosScreen(
              adminId: args?['admin_id'] ?? 0,
              adminUser: args?['admin_user'] ?? {},
            ),
          );
        }
      case RouteNames.adminPricing:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => PricingManagementScreen(
              adminUser: args?['admin_user'] ?? {},
            ),
          );
        }
      
      // Rutas de conductor
      case RouteNames.conductorHome:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ConductorHomeScreen(
              conductorUser: args?['conductor_user'] ?? {},
            ),
          );
        }
      case RouteNames.conductorProfile:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorProfileScreen(
              conductorId: conductorId,
              conductorUser: conductorUser, // Pass the full map
              showBackButton: true,
            ),
            settings: settings,
          );
        }
      case RouteNames.conductorTrips:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorTripsScreen(
              conductorId: conductorId,
              conductorUser: conductorUser,
            ),
            settings: settings,
          );
        }
      case RouteNames.conductorEarnings:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorEarningsScreen(
              conductorId: conductorId,
              conductorUser: conductorUser,
            ),
            settings: settings,
          );
        }
      case RouteNames.conductorVehicle:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorVehicleScreen(
              conductorId: conductorId,
              conductorUser: conductorUser,
            ),
            settings: settings,
          );
        }
      case RouteNames.conductorDocuments:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorDocumentsScreen(
              conductorId: conductorId,
              conductorUser: conductorUser,
            ),
            settings: settings,
          );
        }
      case RouteNames.conductorSettings:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorSettingsScreen(
              conductorId: conductorId,
              conductorUser: conductorUser,
            ),
            settings: settings,
          );
        }
      case RouteNames.conductorHelp:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorHelpScreen(
              conductorId: conductorId,
              conductorUser: conductorUser,
            ),
            settings: settings,
          );
        }
      
      // Agregar más rutas aquí
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No existe la ruta: ${settings.name}'),
            ),
          ),
        );
    }
  }
}

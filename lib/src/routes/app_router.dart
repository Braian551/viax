import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/user/presentation/screens/home_user.dart';
import 'package:viax/src/features/user/presentation/screens/confirm_trip_screen.dart';
import 'package:viax/src/features/user/presentation/screens/enhanced_destination_screen.dart';
import 'package:viax/src/features/user/presentation/screens/user_profile_screen.dart';
import 'package:viax/src/features/user/presentation/screens/trip_history_screen.dart';
import 'package:viax/src/features/user/presentation/screens/settings_screen.dart';
import 'package:viax/src/features/user/presentation/screens/saved_addresses_screen.dart';
import 'package:viax/src/features/user/presentation/screens/user_active_trip_screen.dart';
import 'package:viax/src/features/user/presentation/screens/user_trip_accepted_screen.dart';
import 'package:viax/src/features/user/presentation/screens/searching_driver_screen.dart';
import 'package:viax/src/features/user/presentation/screens/searching_driver/searching_driver_state.dart';
import 'package:viax/src/theme/screens/appearance_settings_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/login_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/register_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/password_recovery_verification_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/pending_deletion_reactivation_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/password_change_verification_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/set_new_password_after_verification_screen.dart';
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
import 'package:viax/src/features/admin/presentation/screens/empresas_management_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/platform_earnings_screen.dart';
import 'package:viax/src/features/admin/presentation/screens/admin_company_payment_reports_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_home_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_profile_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_trips_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_earnings_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_commissions_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_vehicle_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_documents_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_settings_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/conductor_help_screen.dart';
import 'package:viax/src/features/conductor/presentation/screens/active_trip_screen.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/routes/animated_routes.dart';
import 'package:viax/src/widgets/auth_wrapper.dart';

import 'package:viax/src/features/conductor/presentation/screens/driver_registration_screen.dart';
import 'package:viax/src/features/company/presentation/screens/company_home_screen.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/auth/presentation/screens/phone_required_screen.dart';
import 'package:viax/src/features/auth/presentation/screens/empresa_register_screen.dart';
import 'package:viax/src/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:viax/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:viax/src/features/support/presentation/screens/support_tech_home_screen.dart';
import 'package:viax/src/features/support/presentation/screens/support_agent_desk_screen.dart';
import 'package:viax/src/widgets/help/help_screen.dart';
import 'package:viax/src/features/location_sharing/presentation/screens/shared_location_view_screen.dart';
import 'package:viax/src/features/thali/presentation/screens/thali_love_screen.dart';
import 'package:viax/src/features/legal/presentation/screens/legal_acceptance_screen.dart';
import 'package:viax/src/features/legal/presentation/screens/legal_document_screen.dart';
import 'package:viax/src/features/legal/models/legal_document_model.dart';
import 'package:viax/src/features/legal/presentation/screens/background_location_disclosure_screen.dart';
import 'package:viax/src/features/legal/guards/legal_guard.dart';
import 'package:viax/src/global/announcements/announcement_gate.dart';
import 'package:viax/src/global/announcements/announcement_models.dart';

class AppRouter {
  static Widget _buildHomeWithAnnouncements({
    required Widget child,
    required AppAnnouncementRole role,
    int? companyId,
    bool requiresLegalGuard = true,
  }) {
    final announcedChild = AppAnnouncementGate(
      viewer: AppAnnouncementViewer(role: role, companyId: companyId),
      child: child,
    );

    if (!requiresLegalGuard) {
      return announcedChild;
    }

    return LegalGuard(child: announcedChild);
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        // Ruta inicial usada por Navigator(initialRoute: '/')
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.onboarding:
        return FadeSlidePageRoute(
          page: const OnboardingScreen(),
          settings: settings,
        );
      case RouteNames.authWrapper:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      case RouteNames.welcome:
        return FadeSlidePageRoute(
          page: const WelcomeScreen(),
          settings: settings,
        );
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
        return FadeSlidePageRoute(
          page: const PhoneAuthScreen(),
          settings: settings,
        );
      case RouteNames.phoneRequired:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return FadeSlidePageRoute(
            page: PhoneRequiredScreen(userData: args),
            settings: settings,
          );
        }
      case RouteNames.emailAuth:
        return FadeSlidePageRoute(
          page: const EmailAuthScreen(),
          settings: settings,
        );
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
      case RouteNames.forgotPassword:
        return FadeSlidePageRoute(
          page: const ForgotPasswordScreen(),
          settings: settings,
        );
      case RouteNames.passwordRecoveryVerification:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final rawPasswordChangeUserId = args?['passwordChangeUserId'];
          final passwordChangeUserId = rawPasswordChangeUserId is int
              ? rawPasswordChangeUserId
              : int.tryParse(rawPasswordChangeUserId?.toString() ?? '');

          return FadeSlidePageRoute(
            page: PasswordRecoveryVerificationScreen(
              email: args?['email'] ?? '',
              userName: args?['userName'] ?? '',
              passwordChangeUserId: passwordChangeUserId,
            ),
            settings: settings,
          );
        }
      case RouteNames.resetPassword:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return FadeSlidePageRoute(
            page: ResetPasswordScreen(
              email: args?['email'] ?? '',
              userName: args?['userName'] ?? '',
            ),
            settings: settings,
          );
        }
      case RouteNames.pendingDeletionReactivation:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return FadeSlidePageRoute(
            page: PendingDeletionReactivationScreen(
              email: args?['email']?.toString() ?? '',
              password: args?['password']?.toString(),
              deletionScheduledAt: args?['deletionScheduledAt']?.toString(),
              authProvider: args?['authProvider']?.toString(),
              idToken: args?['idToken']?.toString(),
              accessToken: args?['accessToken']?.toString(),
            ),
            settings: settings,
          );
        }
      case RouteNames.passwordChangeVerification:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'];
          final parsedUserId = userId is int
              ? userId
              : int.tryParse(userId?.toString() ?? '0') ?? 0;

          return FadeSlidePageRoute(
            page: PasswordChangeVerificationScreen(userId: parsedUserId),
            settings: settings,
          );
        }
      case RouteNames.passwordChangeSetNew:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'];
          final parsedUserId = userId is int
              ? userId
              : int.tryParse(userId?.toString() ?? '0') ?? 0;

          return FadeSlidePageRoute(
            page: SetNewPasswordAfterVerificationScreen(
              userId: parsedUserId,
              verificationCode: args?['verificationCode']?.toString() ?? '',
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
      case RouteNames.empresaRegister:
        return FadeSlidePageRoute(
          page: const EmpresaRegisterScreen(),
          settings: settings,
        );
      case RouteNames.welcomeSplash:
        return FadeSlidePageRoute(
          page: const WelcomeSplashScreen(),
          settings: settings,
        );

      // Pantallas Sistema Legal
      case RouteNames.legalAcceptance:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final rawUserId = args?['userId'];
          final userId = rawUserId is int
              ? rawUserId
              : int.tryParse(rawUserId?.toString() ?? '');
          return PageRouteBuilder(
            settings: settings,
            opaque: false,
            barrierColor: Colors.transparent,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            pageBuilder: (_, animation, secondaryAnimation) =>
                LegalAcceptanceScreen(
                  role: args?['role'] ?? 'cliente',
                  version: args?['version'] ?? 'v1.0',
                  userId: userId,
                  returnResultOnAccept: args?['returnResultOnAccept'] == true,
                  isBlocking: args?['isBlocking'] != false,
                ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );

              return FadeTransition(opacity: fade, child: child);
            },
          );
        }
      case RouteNames.backgroundLocationDisclosure:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => BackgroundLocationDisclosureScreen(
              role: args?['role']?.toString() ?? '',
            ),
          );
        }

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
      case RouteNames.driverRegistration:
        return FadeSlidePageRoute(
          page: const DriverRegistrationScreen(),
          settings: settings,
        );
      case RouteNames.home:
        // Cuando el usuario se autentique debe ir a la pantalla principal (HomeUserScreen)
        return MaterialPageRoute(
          builder: (_) => _buildHomeWithAnnouncements(
            role: AppAnnouncementRole.client,
            child: const HomeUserScreen(),
          ),
        );

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
      case RouteNames.userSearchingDriver:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final initialFlowStateName =
              (args?['initialFlowState'] ?? args?['flowState'] ?? '')
                  .toString();
          final initialFlowState = SearchFlowState.values.firstWhere(
            (value) => value.name == initialFlowStateName,
            orElse: () => SearchFlowState.searchingDriver,
          );
          final estimatedPriceRaw =
              args?['estimatedPrice'] ??
              args?['precioEstimado'] ??
              args?['precio_estimado'];
          final estimatedPriceLabel = estimatedPriceRaw is num
              ? '\$${estimatedPriceRaw.toStringAsFixed(0)}'
              : estimatedPriceRaw?.toString();

          final solicitudId =
              args?['solicitudId'] ?? args?['solicitud_id'] ?? 0;
          final clienteId = args?['clienteId'] ?? args?['cliente_id'] ?? 0;
          final latitudOrigen =
              (args?['latitudOrigen'] as num?)?.toDouble() ??
              (args?['origen']?['latitud'] as num?)?.toDouble() ??
              0.0;
          final longitudOrigen =
              (args?['longitudOrigen'] as num?)?.toDouble() ??
              (args?['origen']?['longitud'] as num?)?.toDouble() ??
              0.0;
          final latitudDestino =
              (args?['latitudDestino'] as num?)?.toDouble() ??
              (args?['destino']?['latitud'] as num?)?.toDouble() ??
              0.0;
          final longitudDestino =
              (args?['longitudDestino'] as num?)?.toDouble() ??
              (args?['destino']?['longitud'] as num?)?.toDouble() ??
              0.0;
          final direccionOrigen =
              args?['direccionOrigen'] ??
              args?['direccion_origen'] ??
              args?['origen']?['direccion'] ??
              'Origen';
          final direccionDestino =
              args?['direccionDestino'] ??
              args?['direccion_destino'] ??
              args?['destino']?['direccion'] ??
              'Destino';

          return MaterialPageRoute(
            builder: (_) => SearchingDriverScreen(
              solicitudId: solicitudId,
              clienteId: clienteId,
              latitudOrigen: latitudOrigen,
              longitudOrigen: longitudOrigen,
              direccionOrigen: direccionOrigen,
              latitudDestino: latitudDestino,
              longitudDestino: longitudDestino,
              direccionDestino: direccionDestino,
              tipoVehiculo:
                  args?['tipoVehiculo'] ?? args?['tipo_vehiculo'] ?? 'mototaxi',
              initialEmpresaId:
                  args?['initialEmpresaId'] ?? args?['empresa_id'],
              initialCompanyName:
                  args?['initialCompanyName'] ?? args?['empresa_nombre'],
              initialCompanyLogoUrl:
                  args?['initialCompanyLogoUrl'] ?? args?['empresa_logo_url'],
              initialFlowState: initialFlowState,
              estimatedPriceLabel: estimatedPriceLabel,
              paymentLabel:
                  args?['paymentLabel'] ??
                  args?['metodo_pago'] ??
                  'Efectivo o tarjeta',
              serviceFeatures:
                  (args?['serviceFeatures'] as List?)
                      ?.map((item) => item.toString())
                      .toList() ??
                  const [
                    'Seguimiento en tiempo real',
                    'Asignacion continua',
                    'Cobertura ampliada',
                  ],
              companyCandidates:
                  (args?['companyCandidates'] as List?)
                      ?.whereType<Map>()
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList() ??
                  const [],
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
              solicitudId: args?['solicitud_id'] ?? args?['solicitudId'] ?? 0,
              clienteId: args?['cliente_id'] ?? args?['clienteId'] ?? 0,
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

      // Ruta alternativa para navegación desde FAB flotante (cliente)
      case '/user/active-trip':
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => UserActiveTripScreen(
              solicitudId: args?['solicitudId'] ?? 0,
              clienteId: args?['clienteId'] ?? 0,
              origenLat: (args?['origenLat'] as num?)?.toDouble() ?? 0,
              origenLng: (args?['origenLng'] as num?)?.toDouble() ?? 0,
              direccionOrigen: args?['direccionOrigen'] ?? 'Origen',
              destinoLat: (args?['destinoLat'] as num?)?.toDouble() ?? 0,
              destinoLng: (args?['destinoLng'] as num?)?.toDouble() ?? 0,
              direccionDestino: args?['direccionDestino'] ?? 'Destino',
              conductorInfo: args?['conductorInfo'],
            ),
            settings: settings,
          );
        }

      // Ruta para navegación al punto de encuentro (cliente)
      case RouteNames.userTripAccepted:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => UserTripAcceptedScreen(
              solicitudId: args?['solicitudId'] ?? args?['solicitud_id'] ?? 0,
              clienteId: args?['clienteId'] ?? args?['cliente_id'] ?? 0,
              latitudOrigen:
                  (args?['latitudOrigen'] as num?)?.toDouble() ??
                  (args?['latitud_origen'] as num?)?.toDouble() ??
                  0,
              longitudOrigen:
                  (args?['longitudOrigen'] as num?)?.toDouble() ??
                  (args?['longitud_origen'] as num?)?.toDouble() ??
                  0,
              direccionOrigen:
                  args?['direccionOrigen'] ??
                  args?['direccion_origen'] ??
                  'Origen',
              latitudDestino:
                  (args?['latitudDestino'] as num?)?.toDouble() ??
                  (args?['latitud_destino'] as num?)?.toDouble() ??
                  0,
              longitudDestino:
                  (args?['longitudDestino'] as num?)?.toDouble() ??
                  (args?['longitud_destino'] as num?)?.toDouble() ??
                  0,
              direccionDestino:
                  args?['direccionDestino'] ??
                  args?['direccion_destino'] ??
                  'Destino',
              conductorInfo: args?['conductorInfo'] ?? args?['conductor'],
            ),
            settings: settings,
          );
        }

      // Ruta para navegación desde FAB flotante (conductor)
      case '/conductor/active-trip':
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => ConductorActiveTripScreen(
              conductorId: args?['conductorId'] ?? 0,
              solicitudId: args?['solicitudId'],
              clienteId: args?['clienteId'],
              origenLat: (args?['origenLat'] as num?)?.toDouble() ?? 0,
              origenLng: (args?['origenLng'] as num?)?.toDouble() ?? 0,
              destinoLat: (args?['destinoLat'] as num?)?.toDouble() ?? 0,
              destinoLng: (args?['destinoLng'] as num?)?.toDouble() ?? 0,
              direccionOrigen: args?['direccionOrigen'] ?? 'Origen',
              direccionDestino: args?['direccionDestino'] ?? 'Destino',
              clienteNombre: args?['clienteNombre'],
              clienteFoto: args?['clienteFoto'],
              clienteCalificacion: (args?['clienteCalificacion'] as num?)
                  ?.toDouble(),
              initialTripStatus: args?['initialTripStatus'],
            ),
            settings: settings,
          );
        }

      case RouteNames.userProfile:
        return MaterialPageRoute(builder: (_) => const UserProfileScreen());
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
      case RouteNames.appearanceSettings:
        return MaterialPageRoute(
          builder: (_) => const AppearanceSettingsScreen(),
        );
      case RouteNames.editProfile:
        return FadeSlidePageRoute(
          page: const EditProfileScreen(),
          settings: settings,
        );

      case RouteNames.notifications:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => NotificationsScreen(
              userId: args?['userId'] ?? 0,
              currentUser: args?['currentUser'] as Map<String, dynamic>?,
              userType: args?['userType'] as String?,
            ),
          );
        }

      case RouteNames.help:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final userTypeStr = args?['userType'] as String? ?? 'user';
          final userId = args?['userId'] as int?;
          HelpUserType userType;
          switch (userTypeStr) {
            case 'conductor':
              userType = HelpUserType.conductor;
              break;
            case 'company':
              userType = HelpUserType.company;
              break;
            case 'admin':
            case 'administrador':
            case 'soporte_tecnico':
              userType = HelpUserType.admin;
              break;
            default:
              userType = HelpUserType.user;
          }
          return FadeSlidePageRoute(
            page: HelpScreen(userType: userType, userId: userId),
            settings: settings,
          );
        }

      case RouteNames.favoritePlaces:
        return MaterialPageRoute(builder: (_) => const SavedAddressesScreen());
      case RouteNames.promotions:
      case RouteNames.about:
      case RouteNames.trackingTrip:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text(
                'Próximamente',
                style: TextStyle(color: Colors.white),
              ),
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

      case RouteNames.terms:
      case RouteNames.privacy:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => LegalDocumentScreen(
              role: args?['role']?.toString() ?? 'cliente',
              docType: settings.name == RouteNames.privacy
                  ? LegalDocType.privacy
                  : LegalDocType.terms,
            ),
            settings: settings,
          );
        }

      // Rutas de administrador
      case RouteNames.adminHome:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => _buildHomeWithAnnouncements(
              role: AppAnnouncementRole.admin,
              child: AdminHomeScreen(adminUser: args?['admin_user'] ?? {}),
            ),
          );
        }

      case RouteNames.supportHome:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => _buildHomeWithAnnouncements(
              role: AppAnnouncementRole.support,
              child: SupportTechHomeScreen(
                supportUser: args?['support_user'] ?? args?['admin_user'] ?? {},
              ),
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
            builder: (_) => StatisticsScreen(adminId: args?['admin_id'] ?? 0),
          );
        }
      case RouteNames.adminAuditLogs:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => AuditLogsScreen(adminId: args?['admin_id'] ?? 0),
          );
        }
      // Conductores y Docs removido del admin - lo gestiona cada empresa

      case RouteNames.adminEmpresas:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) =>
                EmpresasManagementScreen(adminUser: args?['admin_user'] ?? {}),
          );
        }

      case RouteNames.adminPlatformEarnings:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) =>
                PlatformEarningsScreen(adminId: args?['admin_id'] ?? 0),
          );
        }

      case RouteNames.adminCompanyPaymentReports:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => AdminCompanyPaymentReportsScreen(
              adminId: args?['admin_id'] ?? 0,
              adminUser: args?['admin_user'] ?? {},
            ),
          );
        }

      case RouteNames.adminSupport:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final adminId =
              (args?['admin_id'] as int?) ??
              (args?['admin_user']?['id'] as int?) ??
              0;
          return MaterialPageRoute(
            builder: (_) => SupportAgentDeskScreen(agentId: adminId),
          );
        }

      // Rutas de empresa
      case RouteNames.companyHome:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final user = args?['user'] ?? {};
          final empresaId = user['empresa_id'];
          debugPrint(
            'AppRouter: Navigating to companyHome. User: ${user['nombre']}, EmpresaId: $empresaId',
          );

          return MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => CompanyProvider(empresaId: empresaId),
              child: _buildHomeWithAnnouncements(
                role: AppAnnouncementRole.company,
                companyId: int.tryParse(empresaId?.toString() ?? ''),
                child: CompanyHomeScreen(user: user),
              ),
            ),
          );
        }

      // Rutas de conductor
      case RouteNames.conductorHome:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => _buildHomeWithAnnouncements(
              role: AppAnnouncementRole.conductor,
              child: ConductorHomeScreen(
                conductorUser: args?['conductor_user'] ?? {},
              ),
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
              conductorUser: conductorUser, // Pasa el mapa completo
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
      case RouteNames.conductorCommissions:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final conductorUser = args ?? {};
          final conductorId = conductorUser['id'] ?? 0;
          return FadeSlidePageRoute(
            page: ConductorCommissionsScreen(
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

      case RouteNames.sharedLocationView:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          final token = args?['token'] as String? ?? '';
          return FadeSlidePageRoute(
            page: SharedLocationViewScreen(token: token),
            settings: settings,
          );
        }

      case RouteNames.thaliLove:
        return FadeSlidePageRoute(
          page: const ThaliLoveScreen(),
          settings: settings,
        );

      // Agregar más rutas aquí
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No existe la ruta: ${settings.name}')),
          ),
        );
    }
  }
}

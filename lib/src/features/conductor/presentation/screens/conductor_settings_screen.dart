import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/notifications/services/push_notification_service.dart';
import 'package:viax/src/global/models/app_user_settings.dart';
import 'package:viax/src/global/services/app_user_settings_service.dart';
import 'package:viax/src/global/services/biometric_auth_service.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';
import 'package:viax/src/features/profile/presentation/utils/account_deletion_flow.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/theme_provider.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/settings/settings_widgets.dart';

/// Pantalla de Configuración del Conductor
///
/// Permite gestionar preferencias de la cuenta,
/// notificaciones, privacidad y más.
class ConductorSettingsScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;

  const ConductorSettingsScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
  });

  @override
  State<ConductorSettingsScreen> createState() =>
      _ConductorSettingsScreenState();
}

class _ConductorSettingsScreenState extends State<ConductorSettingsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  // Estados de configuración
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _biometricEnabled = false;
  bool _darkMode = false;
  String _settingsQuery = '';
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSettings();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _headerController.forward();
  }

  Future<void> _loadSettings() async {
    final themeProvider = context.read<ThemeProvider>();
    final settings = await AppUserSettingsService.loadForCurrentUser();

    if (!mounted) return;

    setState(() {
      _notificationsEnabled = settings.notificationsEnabled;
      _soundEnabled = settings.soundEnabled;
      _vibrationEnabled = settings.vibrationEnabled;
      _biometricEnabled = settings.biometricEnabled;
      _darkMode = themeProvider.isDarkMode;
      _isLoadingSettings = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = AppUserSettings(
      notificationsEnabled: _notificationsEnabled,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
      biometricEnabled: _biometricEnabled,
      language: 'es',
    );
    await AppUserSettingsService.saveForCurrentUser(settings);
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _saveSettings();

    if (value) {
      await PushNotificationService.registerCurrentDeviceForUser(
        widget.conductorId,
      );
    } else {
      await PushNotificationService.unregisterCurrentDevice(
        userId: widget.conductorId,
      );
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    final themeProvider = context.read<ThemeProvider>();
    if (value) {
      await themeProvider.setDarkMode();
    } else {
      await themeProvider.setLightMode();
    }

    if (!mounted) return;

    setState(() => _darkMode = value);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final available = await BiometricAuthService.isAvailable();
      if (!available) {
        _showSnackbar('Tu dispositivo no soporta biometría');
        return;
      }

      final authenticated = await BiometricAuthService.authenticateForEnable();
      if (!authenticated) {
        _showSnackbar('No fue posible activar biometría');
        return;
      }
    }

    if (!mounted) return;

    setState(() => _biometricEnabled = value);
    await _saveSettings();
  }

  Future<void> _openChangePasswordScreen() async {
    await Navigator.pushNamed(
      context,
      RouteNames.passwordChangeVerification,
      arguments: {'userId': widget.conductorId},
    );
  }

  Future<void> _openTerms() async {
    final opened = await LegalLinksService.openTerms(role: LegalRole.conductor);
    if (!opened) {
      _showSnackbar('No se pudo abrir Términos y Condiciones');
    }
  }

  Future<void> _openPrivacy() async {
    final opened = await LegalLinksService.openPrivacy(
      role: LegalRole.conductor,
    );
    if (!opened) {
      _showSnackbar('No se pudo abrir Política de Privacidad');
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final rawUserId = widget.conductorUser?['id'] ?? widget.conductorId;
    final userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    final email = widget.conductorUser?['email']?.toString() ?? '';
    final name = widget.conductorUser?['nombre']?.toString() ?? 'Conductor';

    if (userId == null || email.isEmpty) {
      _showSnackbar('No fue posible identificar tu cuenta');
      return;
    }

    await AccountDeletionFlow.start(
      context: context,
      userId: userId,
      email: email,
      userName: name,
      userType: 'conductor',
    );
  }

  bool _matchesSettingsQuery(String title, [String subtitle = '']) {
    if (_settingsQuery.trim().isEmpty) return true;
    final normalized = _settingsQuery.toLowerCase();
    return title.toLowerCase().contains(normalized) ||
        subtitle.toLowerCase().contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      drawer: widget.conductorUser != null
          ? ConductorDrawer(conductorUser: widget.conductorUser!)
          : null,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingSettings)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Buscar configuración...',
                      ),
                      onChanged: (value) {
                        setState(() => _settingsQuery = value);
                        if (value == 'Thaliana062025') {
                          Navigator.pushNamed(context, RouteNames.thaliLove);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Información de cuenta (removida - ya se muestra en Perfil)
                    const SizedBox.shrink(),

                    // Notificaciones
                    SettingsSection(
                      title: 'Notificaciones',
                      children: [
                        if (_matchesSettingsQuery('Notificaciones', 'Recibir alertas de viajes'))
                        SettingsItem(
                          icon: Icons.notifications_rounded,
                          title: 'Notificaciones',
                          subtitle: 'Recibir alertas de viajes',
                          animationIndex: 0,
                          trailing: SettingsToggle(
                            value: _notificationsEnabled,
                            onChanged: _toggleNotifications,
                          ),
                        ),
                        if (_matchesSettingsQuery('Sonidos', 'Sonidos de notificación'))
                        SettingsItem(
                          icon: Icons.volume_up_rounded,
                          title: 'Sonidos',
                          subtitle: 'Sonidos de notificación',
                          animationIndex: 1,
                          trailing: SettingsToggle(
                            value: _soundEnabled,
                            onChanged: (value) {
                              setState(() => _soundEnabled = value);
                              _saveSettings();
                            },
                          ),
                        ),
                        if (_matchesSettingsQuery('Vibración', 'Vibrar al recibir notificaciones'))
                        SettingsItem(
                          icon: Icons.vibration_rounded,
                          title: 'Vibración',
                          subtitle: 'Vibrar al recibir notificaciones',
                          animationIndex: 2,
                          trailing: SettingsToggle(
                            value: _vibrationEnabled,
                            onChanged: (value) {
                              setState(() => _vibrationEnabled = value);
                              _saveSettings();
                            },
                          ),
                        ),
                      ],
                    ),

                    // Privacidad
                    SettingsSection(
                      title: 'Privacidad y Seguridad',
                      children: [
                        if (_matchesSettingsQuery('Cambiar Contraseña', 'Actualiza tu contraseña'))
                        SettingsItem(
                          icon: Icons.lock_rounded,
                          title: 'Cambiar Contraseña',
                          subtitle: 'Actualiza tu contraseña',
                          animationIndex: 3,
                          onTap: _openChangePasswordScreen,
                        ),
                        if (_matchesSettingsQuery('Autenticación Biométrica', 'Usar huella o Face ID'))
                        SettingsItem(
                          icon: Icons.fingerprint_rounded,
                          title: 'Autenticación Biométrica',
                          subtitle: 'Usar huella o Face ID',
                          animationIndex: 4,
                          trailing: SettingsToggle(
                            value: _biometricEnabled,
                            onChanged: _toggleBiometric,
                          ),
                        ),
                      ],
                    ),

                    // Apariencia
                    SettingsSection(
                      title: 'Apariencia',
                      children: [
                        if (_matchesSettingsQuery('Modo Oscuro', 'Cambiar tema de la aplicación'))
                        SettingsItem(
                          icon: Icons.dark_mode_rounded,
                          title: 'Modo Oscuro',
                          subtitle: 'Cambiar tema de la aplicación',
                          animationIndex: 6,
                          trailing: SettingsToggle(
                            value: _darkMode,
                            onChanged: _toggleDarkMode,
                          ),
                        ),
                        if (_matchesSettingsQuery('Idioma', 'Español'))
                        SettingsItem(
                          icon: Icons.language_rounded,
                          title: 'Idioma',
                          subtitle: 'Español',
                          animationIndex: 7,
                          onTap: () {
                            _showSnackbar('Selección de idioma próximamente');
                          },
                        ),
                      ],
                    ),

                    // Sobre la app
                    SettingsSection(
                      title: 'Acerca de',
                      children: [
                        if (_matchesSettingsQuery('Ayuda y Soporte', 'Centro de ayuda y tickets'))
                        SettingsItem(
                          icon: Icons.support_agent_rounded,
                          title: 'Ayuda y Soporte',
                          subtitle: 'Centro de ayuda y tickets',
                          animationIndex: 8,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              RouteNames.conductorHelp,
                              arguments: widget.conductorUser,
                            );
                          },
                        ),
                        if (_matchesSettingsQuery('Versión de la App', '1.0.0'))
                        SettingsItem(
                          icon: Icons.info_rounded,
                          title: 'Versión de la App',
                          subtitle: '1.0.0',
                          animationIndex: 9,
                          trailing: const SizedBox.shrink(),
                        ),
                        if (_matchesSettingsQuery('Términos y Condiciones'))
                        SettingsItem(
                          icon: Icons.description_rounded,
                          title: 'Términos y Condiciones',
                          animationIndex: 10,
                          onTap: _openTerms,
                        ),
                        if (_matchesSettingsQuery('Política de Privacidad'))
                        SettingsItem(
                          icon: Icons.privacy_tip_rounded,
                          title: 'Política de Privacidad',
                          animationIndex: 11,
                          onTap: _openPrivacy,
                        ),
                      ],
                    ),

                    // Zona de peligro
                    SettingsSection(
                      title: 'Zona de Peligro',
                      children: [
                        if (_matchesSettingsQuery('Eliminar Cuenta', 'Programar eliminación segura de la cuenta'))
                        SettingsItem(
                          icon: Icons.delete_forever_rounded,
                          title: 'Eliminar Cuenta',
                          subtitle: 'Programar eliminación segura de la cuenta',
                          iconColor: AppColors.error,
                          animationIndex: 12,
                          onTap: _handleDeleteAccount,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      leading: widget.conductorUser != null
          ? IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            )
          : IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _headerController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Configuración',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Personaliza tu experiencia',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}

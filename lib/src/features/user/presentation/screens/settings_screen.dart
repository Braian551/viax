import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/conductor/presentation/widgets/settings/settings_widgets.dart';
import 'package:viax/src/features/profile/presentation/utils/account_deletion_flow.dart';
import 'package:viax/src/features/notifications/services/push_notification_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/global/models/app_user_settings.dart';
import 'package:viax/src/global/services/app_user_settings_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/biometric_auth_service.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  int? _userId;
  String _userEmail = '';
  String _userName = 'Usuario';
  bool _isLoadingSettings = true;

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _biometricEnabled = false;
  bool _darkMode = false;
  String _settingsQuery = '';

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
    final session = await UserService.getSavedSession();
    final settings = await AppUserSettingsService.loadForCurrentUser();

    final rawUserId = session?['id'];
    final userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');

    if (!mounted) return;

    setState(() {
      _userId = userId;
      _userEmail = session?['email']?.toString() ?? '';
      final firstName = session?['nombre']?.toString() ?? '';
      final lastName = session?['apellido']?.toString() ?? '';
      _userName = ('$firstName $lastName').trim().isEmpty
          ? 'Usuario'
          : ('$firstName $lastName').trim();
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

    if (_userId == null) return;

    if (value) {
      await PushNotificationService.registerCurrentDeviceForUser(_userId!);
    } else {
      await PushNotificationService.unregisterCurrentDevice(userId: _userId);
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
        _showSnackbar('Tu dispositivo no soporta biometria');
        return;
      }

      final authenticated = await BiometricAuthService.authenticateForEnable();
      if (!authenticated) {
        _showSnackbar('No fue posible activar biometria');
        return;
      }
    }

    if (!mounted) return;

    setState(() => _biometricEnabled = value);
    await _saveSettings();
  }

  Future<void> _openChangePasswordScreen() async {
    if (_userId == null) {
      _showSnackbar('No se pudo identificar tu usuario');
      return;
    }

    await Navigator.pushNamed(
      context,
      RouteNames.passwordChangeVerification,
      arguments: {'userId': _userId},
    );
  }

  Future<void> _openTerms() async {
    final opened = await LegalLinksService.openTerms(role: LegalRole.cliente);
    if (!opened) {
      _showSnackbar('No se pudo abrir Términos y Condiciones');
    }
  }

  Future<void> _openPrivacy() async {
    final opened = await LegalLinksService.openPrivacy(role: LegalRole.cliente);
    if (!opened) {
      _showSnackbar('No se pudo abrir Política de Privacidad');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;

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
    if (_userId == null || _userEmail.isEmpty) {
      _showSnackbar('No se pudo identificar tu cuenta');
      return;
    }

    await AccountDeletionFlow.start(
      context: context,
      userId: _userId!,
      email: _userEmail,
      userName: _userName,
      userType: 'cliente',
    );
  }

  bool _matchesSettingsQuery(String title, [String subtitle = '']) {
    if (_settingsQuery.trim().isEmpty) return true;
    final normalized = _settingsQuery.toLowerCase();
    return title.toLowerCase().contains(normalized) ||
        subtitle.toLowerCase().contains(normalized);
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                        if (_matchesSettingsQuery('Sonidos', 'Sonidos de notificacion'))
                        SettingsItem(
                          icon: Icons.volume_up_rounded,
                          title: 'Sonidos',
                          subtitle: 'Sonidos de notificacion',
                          animationIndex: 1,
                          trailing: SettingsToggle(
                            value: _soundEnabled,
                            onChanged: (value) {
                              setState(() => _soundEnabled = value);
                              _saveSettings();
                            },
                          ),
                        ),
                        if (_matchesSettingsQuery('Vibracion', 'Vibrar al recibir notificaciones'))
                        SettingsItem(
                          icon: Icons.vibration_rounded,
                          title: 'Vibracion',
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
                    SettingsSection(
                      title: 'Privacidad y Seguridad',
                      children: [
                        if (_matchesSettingsQuery('Cambiar Contrasena', 'Actualiza tu contrasena'))
                        SettingsItem(
                          icon: Icons.lock_rounded,
                          title: 'Cambiar Contrasena',
                          subtitle: 'Actualiza tu contrasena',
                          animationIndex: 3,
                          onTap: _openChangePasswordScreen,
                        ),
                        if (_matchesSettingsQuery('Autenticacion Biometrica', 'Usar huella o Face ID'))
                        SettingsItem(
                          icon: Icons.fingerprint_rounded,
                          title: 'Autenticacion Biometrica',
                          subtitle: 'Usar huella o Face ID',
                          animationIndex: 4,
                          trailing: SettingsToggle(
                            value: _biometricEnabled,
                            onChanged: _toggleBiometric,
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Apariencia',
                      children: [
                        if (_matchesSettingsQuery('Modo Oscuro', 'Cambiar tema de la aplicacion'))
                        SettingsItem(
                          icon: Icons.dark_mode_rounded,
                          title: 'Modo Oscuro',
                          subtitle: 'Cambiar tema de la aplicacion',
                          animationIndex: 5,
                          trailing: SettingsToggle(
                            value: _darkMode,
                            onChanged: _toggleDarkMode,
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Cuenta',
                      children: [
                        if (_matchesSettingsQuery('Eliminar cuenta', 'Programar eliminación segura de la cuenta'))
                        SettingsItem(
                          icon: Icons.delete_forever_rounded,
                          title: 'Eliminar cuenta',
                          subtitle: 'Programar eliminación segura de la cuenta',
                          animationIndex: 6,
                          iconColor: AppColors.error,
                          onTap: _handleDeleteAccount,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Acerca de',
                      children: [
                        if (_matchesSettingsQuery('Ayuda y Soporte', 'Centro de ayuda y tickets'))
                        SettingsItem(
                          icon: Icons.support_agent_rounded,
                          title: 'Ayuda y Soporte',
                          subtitle: 'Centro de ayuda y tickets',
                          animationIndex: 7,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              RouteNames.help,
                              arguments: {
                                'userType': 'user',
                                'userId': _userId,
                              },
                            );
                          },
                        ),
                        if (_matchesSettingsQuery('Términos y Condiciones', 'Condiciones de uso para clientes'))
                        SettingsItem(
                          icon: Icons.description_rounded,
                          title: 'Términos y Condiciones',
                          subtitle: 'Condiciones de uso para clientes',
                          animationIndex: 8,
                          onTap: _openTerms,
                        ),
                        if (_matchesSettingsQuery('Política de Privacidad', 'Tratamiento de datos personales'))
                        SettingsItem(
                          icon: Icons.privacy_tip_rounded,
                          title: 'Política de Privacidad',
                          subtitle: 'Tratamiento de datos personales',
                          animationIndex: 9,
                          onTap: _openPrivacy,
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
      leading: IconButton(
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
                            'Configuracion',
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

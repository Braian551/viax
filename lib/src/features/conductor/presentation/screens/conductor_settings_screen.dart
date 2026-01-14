import 'package:flutter/material.dart';
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
  State<ConductorSettingsScreen> createState() => _ConductorSettingsScreenState();
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
  bool _locationSharing = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _headerController.forward();
  }

  void _loadSettings() {
    // Cargar configuraciones guardadas
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _darkMode = isDark;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                  // Información de cuenta (removida - ya se muestra en Perfil)
                  const SizedBox.shrink(),

                  // Notificaciones
                  SettingsSection(
                    title: 'Notificaciones',
                    children: [
                      SettingsItem(
                        icon: Icons.notifications_rounded,
                        title: 'Notificaciones',
                        subtitle: 'Recibir alertas de viajes',
                        animationIndex: 0,
                        trailing: SettingsToggle(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                          },
                        ),
                      ),
                      SettingsItem(
                        icon: Icons.volume_up_rounded,
                        title: 'Sonidos',
                        subtitle: 'Sonidos de notificación',
                        animationIndex: 1,
                        trailing: SettingsToggle(
                          value: _soundEnabled,
                          onChanged: (value) {
                            setState(() => _soundEnabled = value);
                          },
                        ),
                      ),
                      SettingsItem(
                        icon: Icons.vibration_rounded,
                        title: 'Vibración',
                        subtitle: 'Vibrar al recibir notificaciones',
                        animationIndex: 2,
                        trailing: SettingsToggle(
                          value: _vibrationEnabled,
                          onChanged: (value) {
                            setState(() => _vibrationEnabled = value);
                          },
                        ),
                      ),
                    ],
                  ),

                  // Privacidad
                  SettingsSection(
                    title: 'Privacidad y Seguridad',
                    children: [
                      SettingsItem(
                        icon: Icons.location_on_rounded,
                        title: 'Ubicación en tiempo real',
                        subtitle: 'Compartir ubicación mientras conduces',
                        animationIndex: 3,
                        trailing: SettingsToggle(
                          value: _locationSharing,
                          onChanged: (value) {
                            setState(() => _locationSharing = value);
                          },
                        ),
                      ),
                      SettingsItem(
                        icon: Icons.lock_rounded,
                        title: 'Cambiar Contraseña',
                        subtitle: 'Actualiza tu contraseña',
                        animationIndex: 4,
                        onTap: () {
                          _showSnackbar('Cambiar contraseña próximamente');
                        },
                      ),
                      SettingsItem(
                        icon: Icons.fingerprint_rounded,
                        title: 'Autenticación Biométrica',
                        subtitle: 'Usar huella o Face ID',
                        animationIndex: 5,
                        onTap: () {
                          _showSnackbar('Biometría próximamente');
                        },
                      ),
                    ],
                  ),

                  // Apariencia
                  SettingsSection(
                    title: 'Apariencia',
                    children: [
                      SettingsItem(
                        icon: Icons.dark_mode_rounded,
                        title: 'Modo Oscuro',
                        subtitle: 'Cambiar tema de la aplicación',
                        animationIndex: 6,
                        trailing: SettingsToggle(
                          value: _darkMode,
                          onChanged: (value) {
                            setState(() => _darkMode = value);
                            _showSnackbar('Cambio de tema próximamente');
                          },
                        ),
                      ),
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
                      SettingsItem(
                        icon: Icons.info_rounded,
                        title: 'Versión de la App',
                        subtitle: '1.0.0',
                        animationIndex: 8,
                        trailing: const SizedBox.shrink(),
                      ),
                      SettingsItem(
                        icon: Icons.description_rounded,
                        title: 'Términos y Condiciones',
                        animationIndex: 9,
                        onTap: () {
                          _showSnackbar('Términos próximamente');
                        },
                      ),
                      SettingsItem(
                        icon: Icons.privacy_tip_rounded,
                        title: 'Política de Privacidad',
                        animationIndex: 10,
                        onTap: () {
                          _showSnackbar('Privacidad próximamente');
                        },
                      ),
                    ],
                  ),

                  // Zona de peligro
                  SettingsSection(
                    title: 'Zona de Peligro',
                    children: [
                      SettingsItem(
                        icon: Icons.delete_forever_rounded,
                        title: 'Eliminar Cuenta',
                        subtitle: 'Esta acción no se puede deshacer',
                        iconColor: AppColors.error,
                        animationIndex: 11,
                        onTap: () {
                          _showDeleteAccountDialog();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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

  void _showDeleteAccountDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(
              'Eliminar Cuenta',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar tu cuenta? Esta acción no se puede deshacer y perderás todos tus datos.',
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackbar('Eliminación de cuenta próximamente');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

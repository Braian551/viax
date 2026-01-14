
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../theme/app_colors.dart';
import '../../providers/conductor_profile_provider.dart';
import '../../models/conductor_profile_model.dart';
import 'license_registration_screen.dart';
import 'vehicle_only_registration_screen.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/dialogs/logout_dialog.dart';
import 'package:viax/src/routes/route_names.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';

class ConductorProfileScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;
  final bool showBackButton;

  const ConductorProfileScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
    this.showBackButton = true,
  });

  @override
  State<ConductorProfileScreen> createState() => _ConductorProfileScreenState();
}

class _ConductorProfileScreenState extends State<ConductorProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Map<String, dynamic>? _conductorUser;

  @override
  void initState() {
    super.initState();
    _conductorUser = widget.conductorUser;
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ConductorProfileProvider>(
        context,
        listen: false,
      ).loadProfile(widget.conductorId);
      _animationController.forward();
    });
  }

  Future<void> _editProfile() async {
    if (_conductorUser == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(),
        settings: RouteSettings(
          arguments: {
            'userId': widget.conductorId,
            'nombre': _conductorUser!['nombre'],
            'apellido': _conductorUser!['apellido'],
            'email': _conductorUser!['email'],
            'telefono': _conductorUser!['telefono'],
            'foto_perfil': _conductorUser!['foto_perfil'],
          },
        ),
      ),
    );

    if (result == true) {
      // Recargar datos del usuario
      final updatedSession = await UserService.getSavedSession();
      if (updatedSession != null && mounted) {
        setState(() {
          _conductorUser = updatedSession;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Consumer<ConductorProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildShimmerLoading(isDark);
          }

          final profile = provider.profile;
          if (profile == null) {
            return _buildErrorView(provider, isDark);
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(isDark, profile),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.aprobado && profile.estadoVerificacion == VerificationStatus.aprobado)
                        _buildApprovedContent(profile, isDark)
                      else
                        _buildVerificationContent(profile, isDark),
                      
                      const SizedBox(height: 24),
                      _buildLogoutButton(isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, ConductorProfileModel profile) {
    final name = _conductorUser?['nombre'] ?? 'Conductor';
    final lastName = _conductorUser?['apellido'] ?? '';
    final fullName = '$name $lastName'.trim();
    final rating = double.tryParse(_conductorUser?['calificacion']?.toString() ?? '5.0') ?? 5.0;
    final trips = _conductorUser?['viajes'] ?? 0;
    final photoKey = _conductorUser?['foto_perfil'];
    final photoUrl = photoKey != null ? UserService.getR2ImageUrl(photoKey) : null;
    
    // Calcular tiempo en la plataforma
    String timeOnPlatform = '0 días';
    String timeLabel = 'Tiempo';
    
    if (_conductorUser?['fecha_registro'] != null) {
      try {
        final registrationDate = DateTime.parse(_conductorUser!['fecha_registro']);
        final now = DateTime.now();
        final difference = now.difference(registrationDate);
        final days = difference.inDays;
        
        if (days < 30) {
          timeOnPlatform = '$days';
          timeLabel = 'Días';
        } else if (days < 365) {
          final months = (days / 30).floor();
          timeOnPlatform = '$months';
          timeLabel = months == 1 ? 'Mes' : 'Meses';
        } else {
          final years = (days / 365).toStringAsFixed(1);
          timeOnPlatform = years;
          timeLabel = 'Años';
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }
    
    return SliverAppBar(
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.primary,
      elevation: 0,
      leading: widget.showBackButton
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
            ),
            onPressed: _editProfile,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            
            // Profile Info
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Avatar
                  Hero(
                    tag: 'profile_avatar',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        backgroundImage: photoUrl != null 
                            ? NetworkImage(photoUrl) 
                            : null,
                        child: photoUrl == null 
                            ? Text(
                                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    fullName.isNotEmpty ? fullName : name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Rating Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$rating',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Nivel Oro', // Placeholder for tier
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem('Viajes', '$trips'),
                      _buildVerticalDivider(),
                      _buildStatItem(timeLabel, timeOnPlatform),
                      _buildVerticalDivider(),
                      _buildStatItem('Tasa', '98%'), // Placeholder as requested, or can be dynamic if data exists
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovedContent(ConductorProfileModel profile, bool isDark) {
    return Column(
      children: [
        _buildSectionTitle('Información del Vehículo', isDark),
        const SizedBox(height: 12),
        _buildVehicleCard(profile, isDark),
        
        const SizedBox(height: 24),
        _buildSectionTitle('Documentos', isDark),
        const SizedBox(height: 12),
        _buildDocumentsList(profile, isDark),
        
        const SizedBox(height: 24),
        _buildSectionTitle('Cuenta', isDark),
        const SizedBox(height: 12),
        _buildSettingsList(isDark),
      ],
    );
  }

  Widget _buildVerificationContent(ConductorProfileModel profile, bool isDark) {
    return Column(
      children: [
        _buildVerificationStatusCard(profile, isDark),
        const SizedBox(height: 24),
        _buildSectionTitle('Pasos para activar tu cuenta', isDark),
        const SizedBox(height: 16),
        _buildVerificationStep(
          title: 'Licencia de Conducción',
          subtitle: profile.licencia?.isComplete == true 
              ? 'Verificado' 
              : 'Sube tu licencia vigente',
          icon: Icons.badge_rounded,
          isCompleted: profile.licencia?.isComplete == true,
          isDark: isDark,
          onTap: () => _editLicense(profile.licencia),
        ),
        const SizedBox(height: 12),
        _buildVerificationStep(
          title: 'Información del Vehículo',
          subtitle: profile.vehiculo?.isBasicComplete == true 
              ? 'Registrado' 
              : 'Marca, modelo y placa',
          icon: Icons.directions_car_rounded,
          isCompleted: profile.vehiculo?.isBasicComplete == true,
          isDark: isDark,
          onTap: () => _editVehicle(profile.vehiculo),
        ),
        const SizedBox(height: 12),
        _buildVerificationStep(
          title: 'Documentos del Vehículo',
          subtitle: profile.vehiculo?.isDocumentsComplete == true 
              ? 'Subidos' 
              : 'SOAT y Tarjeta de Propiedad',
          icon: Icons.folder_rounded,
          isCompleted: profile.vehiculo?.isDocumentsComplete == true,
          isDark: isDark,
          onTap: () => _editVehicle(profile.vehiculo), // Assuming same screen for now
        ),
        
        const SizedBox(height: 32),
        if (profile.isProfileComplete && !profile.aprobado && profile.estadoVerificacion != VerificationStatus.enRevision)
          _buildSubmitButton(profile, isDark),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVehicleCard(ConductorProfileModel profile, bool isDark) {
    final vehicle = profile.vehiculo;
    if (vehicle == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car_filled_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.marca} ${vehicle.modelo}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vehicle.placa.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: () => _editVehicle(vehicle),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(ConductorProfileModel profile, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListItem(
            title: 'Licencia de Conducción',
            subtitle: profile.licencia?.isValid == true ? 'Vigente' : 'Revisar',
            icon: Icons.badge_rounded,
            isDark: isDark,
            onTap: () => _editLicense(profile.licencia),
            showDivider: true,
            statusColor: profile.licencia?.isValid == true ? AppColors.success : AppColors.error,
          ),
          _buildListItem(
            title: 'SOAT',
            subtitle: profile.vehiculo?.fotoSoat != null ? 'Subido' : 'Pendiente',
            icon: Icons.description_rounded,
            isDark: isDark,
            onTap: () => _editVehicle(profile.vehiculo),
            showDivider: true,
            statusColor: profile.vehiculo?.fotoSoat != null ? AppColors.success : AppColors.warning,
          ),
          _buildListItem(
            title: 'Tarjeta de Propiedad',
            subtitle: profile.vehiculo?.fotoTarjetaPropiedad != null ? 'Subido' : 'Pendiente',
            icon: Icons.credit_card_rounded,
            isDark: isDark,
            onTap: () => _editVehicle(profile.vehiculo),
            showDivider: false,
            statusColor: profile.vehiculo?.fotoTarjetaPropiedad != null ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListItem(
            title: 'Notificaciones',
            icon: Icons.notifications_rounded,
            isDark: isDark,
            onTap: () => _showComingSoon('Notificaciones'),
            showDivider: true,
          ),
          _buildListItem(
            title: 'Idioma',
            icon: Icons.language_rounded,
            isDark: isDark,
            onTap: () => _showComingSoon('Idioma'),
            showDivider: true,
            trailingText: 'Español',
          ),
/*           _buildListItem(
             title: 'Ayuda y Soporte',
             icon: Icons.help_outline_rounded,
             isDark: isDark,
             onTap: () => _showComingSoon('Ayuda'),
             showDivider: false,
           ), */
        ],
      ),
    );
  }

  Widget _buildListItem({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    bool showDivider = false,
    Color? statusColor,
    String? trailingText,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (statusColor ?? AppColors.primary).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: statusColor ?? AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailingText != null)
                  Text(
                    trailingText,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  size: 16,
                ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              indent: 68,
              color: isDark ? Colors.white10 : Colors.grey[100],
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard(ConductorProfileModel profile, bool isDark) {
    Color color;
    String title;
    String desc;
    IconData icon;

    switch (profile.estadoVerificacion) {
      case VerificationStatus.pendiente:
        color = AppColors.warning;
        title = 'Verificación Pendiente';
        desc = 'Completa los pasos para activar tu cuenta';
        icon = Icons.hourglass_empty_rounded;
        break;
      case VerificationStatus.enRevision:
        color = AppColors.info;
        title = 'En Revisión';
        desc = 'Estamos revisando tus documentos';
        icon = Icons.search_rounded;
        break;
      case VerificationStatus.rechazado:
        color = AppColors.error;
        title = 'Documentos Rechazados';
        desc = 'Por favor revisa los documentos marcados';
        icon = Icons.error_outline_rounded;
        break;
      default:
        color = AppColors.success;
        title = 'Aprobado';
        desc = 'Tu cuenta está activa';
        icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted 
              ? AppColors.success.withValues(alpha: 0.3) 
              : (isDark ? Colors.white10 : Colors.grey[200]!),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isCompleted ? AppColors.success : AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: isCompleted ? AppColors.success : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white24 : Colors.grey[300],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ConductorProfileModel profile, bool isDark) {
    final provider = Provider.of<ConductorProfileProvider>(context, listen: false);
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: provider.isLoading
            ? null
            : () async {
                final result = await provider.submitForVerification(
                  widget.conductorId,
                );
                if (!mounted) return;
                
                if (result) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Perfil enviado para verificación!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  await provider.loadProfile(widget.conductorId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? 'Error'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        child: provider.isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Enviar Solicitud',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return TextButton(
      onPressed: () async {
        print('DEBUG: ProfileScreen - Mostrando diálogo de logout');
        final shouldLogout = await LogoutDialog.show(context);
        print('DEBUG: ProfileScreen - Logout confirmado? $shouldLogout');

        if (shouldLogout == true && mounted) {
          print('DEBUG: ProfileScreen - Limpiando sesión...');
          await UserService.clearSession();
          print('DEBUG: ProfileScreen - Sesión limpiada. Navegando a welcome...');
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.welcome, (route) => false);
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        foregroundColor: AppColors.error,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, size: 20),
          SizedBox(width: 8),
          Text(
            'Cerrar Sesión',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(height: 280, color: Colors.white),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ConductorProfileProvider provider, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Error al cargar perfil',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => provider.loadProfile(widget.conductorId),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editLicense(license) async {
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LicenseRegistrationScreen(
          conductorId: widget.conductorId,
          existingLicense: license,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Provider.of<ConductorProfileProvider>(context, listen: false).loadProfile(widget.conductorId);
    }
  }

  void _editVehicle(vehicle) async {
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleOnlyRegistrationScreen(
          conductorId: widget.conductorId,
          existingVehicle: vehicle,
          existingLicense: Provider.of<ConductorProfileProvider>(context, listen: false).profile?.licencia,
          conductorUser: widget.conductorUser,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Provider.of<ConductorProfileProvider>(context, listen: false).loadProfile(widget.conductorId);
    }
  }

  void _showComingSoon(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature próximamente'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

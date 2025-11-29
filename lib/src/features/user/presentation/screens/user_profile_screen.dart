import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

/// Pantalla completa de perfil del usuario
/// Incluye informaciÃ³n personal, foto, ajustes y opciones
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _userData;
  // ignore: unused_field
  Map<String, dynamic>? _locationData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final session = await UserService.getSavedSession();
      if (session != null) {
        final userId = session['id'] as int?;
        final email = session['email'] as String?;
        
        final profile = await UserService.getProfile(userId: userId, email: email);
        if (profile != null && profile['success'] == true) {
          setState(() {
            _userData = profile['user'] as Map<String, dynamic>?;
            _locationData = profile['location'] as Map<String, dynamic>?;
            _loading = false;
          });
        }
      }
    } catch (e) {
      print('Error cargando perfil: $e');
      setState(() => _loading = false);
    }
  }

  void _logout() async {
    await UserService.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),
              _buildProfileCard(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildMenuSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Mi Perfil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFFFFF00)),
            onPressed: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final nombre = _userData?['nombre'] as String? ?? 'Usuario';
    final apellido = _userData?['apellido'] as String? ?? '';
    final email = _userData?['email'] as String? ?? '';
    final telefono = _userData?['telefono'] as String? ?? 'No especificado';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFFF00).withOpacity(0.3),
                            const Color(0xFFFFFF00).withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Color(0xFFFFFF00),
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFF00),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.black, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$nombre $apellido',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email_outlined, color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_outlined, color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      telefono,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.route,
              title: 'Viajes',
              value: '24',
              color: const Color(0xFFFFFF00),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.credit_card,
              title: 'Pagos',
              value: '3',
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.history,
            title: 'Historial de viajes',
            subtitle: 'Ver todos tus viajes',
            onTap: () => Navigator.pushNamed(context, '/trip_history'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.credit_card,
            title: 'MÃ©todos de pago',
            subtitle: 'Administrar tus pagos',
            onTap: () => Navigator.pushNamed(context, '/payment_methods'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.favorite_border,
            title: 'Lugares favoritos',
            subtitle: 'Guarda tus direcciones frecuentes',
            onTap: () => Navigator.pushNamed(context, '/favorite_places'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.percent,
            title: 'Promociones',
            subtitle: 'Cupones y descuentos disponibles',
            onTap: () => Navigator.pushNamed(context, '/promotions'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'ConfiguraciÃ³n',
            subtitle: 'Ajustes y preferencias',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Ayuda y soporte',
            subtitle: 'ContÃ¡ctanos o consulta FAQ',
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'VersiÃ³n y tÃ©rminos legales',
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
          const SizedBox(height: 20),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFF00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFFFFFF00), size: 24),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Cerrar sesiÃ³n',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

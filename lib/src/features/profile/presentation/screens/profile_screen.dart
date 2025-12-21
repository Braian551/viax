import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/features/map/presentation/screens/location_picker_screen.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// A widget that renders the profile content without its own Scaffold/AppBar
/// so it can be embedded as a tab inside a parent scaffold.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _location;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final sess = await UserService.getSavedSession();
    if (mounted) {
      setState(() {
        _session = sess;
      });
    }

    if (sess != null) {
      final id = sess['id'] as int?;
      final email = sess['email'] as String?;
      final profile = await UserService.getProfile(userId: id, email: email);
      if (!mounted) return;
      if (profile != null && profile['success'] == true) {
        setState(() {
            _profileData = profile['user'] as Map<String, dynamic>?;
            _location = profile['location'] as Map<String, dynamic>?;
        });
      }
    }

    // If no saved session, maybe we were opened with route args (e.g. after register)
    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map) {
          final emailArg = args['email'] as String?;
          final idArg = args['userId'] as int?;
          if (emailArg != null || idArg != null) {
            final profile = await UserService.getProfile(userId: idArg, email: emailArg);
            if (profile != null && profile['success'] == true) {
              if (mounted) {
                setState(() {
                  _profileData = profile['user'] as Map<String, dynamic>?;
                  _location = profile['location'] as Map<String, dynamic>?;
                });
              }
            }
          }
        }
        if (mounted) setState(() => _loading = false);
      });
      return;
    }

    setState(() => _loading = false);
  }

  void _logout() async {
    await UserService.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Widget _buildProfileCard(String? email) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
              border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFF00),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.black, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileData != null ? '${_profileData!['nombre'] ?? ''} ${_profileData!['apellido'] ?? ''}' : (email ?? 'Usuario'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email ?? 'No hay sesiÃ³n',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _location != null && (_location!['direccion'] ?? '').toString().isNotEmpty
                          ? (_location!['direccion'] ?? '')
                          : (_profileData != null && (_profileData!['direccion'] ?? '').toString().isNotEmpty ? _profileData!['direccion'] : 'Sin direcciÃ³n'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const LocationPickerScreen()),
            );
            setState(() => _loading = true);
            await _loadSession();
            if (mounted) CustomSnackbar.showSuccess(context, message: 'DirecciÃ³n actualizada correctamente');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFF00),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, color: Colors.black, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Editar direcciÃ³n',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _logout,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.exit_to_app, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Cerrar sesiÃ³n',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _session?['email'] as String?;

    return _loading
        ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00))))
        : SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Mi perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileCard(email),
                  const SizedBox(height: 30),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _location;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final sess = await UserService.getSavedSession();
    setState(() {
      _session = sess;
    });

    if (sess != null) {
      final id = sess['id'] as int?;
      final email = sess['email'] as String?;
      final profile = await UserService.getProfile(userId: id, email: email);
      if (profile != null && profile['success'] == true) {
        setState(() {
          _profileData = profile['user'] as Map<String, dynamic>?;
          _location = profile['location'] as Map<String, dynamic>?;
        });
      }
      setState(() => _loading = false);
      return;
    }

    // Try to get profile using route args if no saved session
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final emailArg = args['email'] as String?;
        final idArg = args['userId'] as int?;
        if (emailArg != null || idArg != null) {
          final profile = await UserService.getProfile(userId: idArg, email: emailArg);
          if (profile != null && profile['success'] == true) {
            if (mounted) {
              setState(() {
                _profileData = profile['user'] as Map<String, dynamic>?;
                _location = profile['location'] as Map<String, dynamic>?;
              });
            }
          }
        }
      }
      if (mounted) setState(() => _loading = false);
    });
  }

  void _logout() async {
    await UserService.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _session?['email'] as String?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Perfil', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00))))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: Color(0xFF1A1A1A),
                            child: Icon(Icons.person, color: Color(0xFFFFFF00), size: 32),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profileData != null ? '${_profileData!['nombre'] ?? ''} ${_profileData!['apellido'] ?? ''}' : (email ?? 'Usuario'),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  email ?? 'No hay sesiÃ³n',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _location != null && (_location!['direccion'] ?? '').toString().isNotEmpty
                                      ? (_location!['direccion'] ?? '')
                                      : (_profileData != null && (_profileData!['direccion'] ?? '').toString().isNotEmpty ? _profileData!['direccion'] : ''),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Abrir LocationPicker para editar direcciÃ³n; al volver recargar perfil
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const LocationPickerScreen()),
                      );
                      setState(() => _loading = true);
                      await _loadSession();
                      if (mounted) CustomSnackbar.showSuccess(context, message: 'DirecciÃ³n actualizada correctamente');
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Editar direcciÃ³n'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFFF00), foregroundColor: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Cerrar sesiÃ³n'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }
}

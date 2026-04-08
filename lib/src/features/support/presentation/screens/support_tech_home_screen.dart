import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:viax/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:viax/src/features/support/presentation/screens/support_agent_desk_screen.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';

class SupportTechHomeScreen extends StatefulWidget {
  final Map<String, dynamic> supportUser;

  const SupportTechHomeScreen({
    super.key,
    required this.supportUser,
  });

  @override
  State<SupportTechHomeScreen> createState() => _SupportTechHomeScreenState();
}

class _SupportTechHomeScreenState extends State<SupportTechHomeScreen> {
  int get _supportId => int.tryParse(widget.supportUser['id']?.toString() ?? '0') ?? 0;

  String get _supportName {
    final nombre = widget.supportUser['nombre']?.toString() ?? '';
    final apellido = widget.supportUser['apellido']?.toString() ?? '';
    final fullName = ('$nombre $apellido').trim();
    return fullName.isEmpty ? 'Soporte Tecnico' : fullName;
  }

  Future<void> _openNotifications() async {
    if (_supportId <= 0) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          userId: _supportId,
          currentUser: widget.supportUser,
          userType: 'soporte_tecnico',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await UserService.clearSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, RouteNames.welcome, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.92)
                  : AppColors.lightSurface.withValues(alpha: 0.92),
            ),
          ),
        ),
        title: const Text(
          'Panel de Soporte',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _supportName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gestiona tickets, responde usuarios y da seguimiento operativo.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.support_agent_rounded,
            title: 'Abrir mesa de soporte',
            subtitle: 'Bandeja de tickets y chat de soporte',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportAgentDeskScreen(agentId: _supportId),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.help_outline_rounded,
            title: 'Ayuda y centro de conocimiento',
            subtitle: 'FAQs y canales de soporte internos',
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.help,
                arguments: {
                  'userType': 'soporte_tecnico',
                  'userId': _supportId,
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.notifications_active_outlined,
            title: 'Notificaciones',
            subtitle: 'Revisa actividad nueva de tickets',
            onTap: _openNotifications,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.14),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}

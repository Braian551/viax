import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

class UserSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final TextEditingController controller;

  const UserSearchField({
    Key? key,
    required this.onChanged,
    required this.onClear,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, email o teléfono...',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class UserFilterTab extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const UserFilterTab({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserListCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final Function(String) onAction;

  const UserListCard({
    Key? key,
    required this.user,
    required this.onTap,
    required this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = user['es_activo'] == 1;
    final tipoUsuario = user['tipo_usuario'] ?? '';
    final userColor = _getUserTypeColor(tipoUsuario);
    final nombre = user['nombre'] ?? 'Sin';
    final apellido = user['apellido'] ?? 'nombre';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: userColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: userColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          nombre[0].toUpperCase(),
                          style: TextStyle(
                            color: userColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$nombre $apellido',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user['email'] ?? 'Sin email',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildTag(context, _getUserTypeLabel(tipoUsuario), userColor),
                              const SizedBox(width: 8),
                              _buildTag(
                                context,
                                isActive ? 'Activo' : 'Inactivo',
                                isActive ? Colors.green : Colors.red,
                                isDot: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      onSelected: onAction,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Ver detalles'),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        PopupMenuItem(
                          value: isActive ? 'deactivate' : 'activate',
                          child: Text(isActive ? 'Desactivar' : 'Activar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label, Color color, {bool isDot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getUserTypeColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'administrador':
        return const Color(0xFFf5576c);
      case 'conductor':
        return const Color(0xFF667eea);
      case 'cliente':
        return const Color(0xFF11998e);
      case 'empresa':
        return const Color(0xFFFF9800); // Orange for company
      default:
        return Colors.grey;
    }
  }

  String _getUserTypeLabel(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'administrador':
        return 'Admin';
      case 'conductor':
        return 'Conductor';
      case 'cliente':
        return 'Cliente';
      case 'empresa':
        return 'Empresa';
      default:
        return 'Usuario';
    }
  }
}

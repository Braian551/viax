import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../conductor/presentation/widgets/components/company_picker_sheet.dart';

/// Card que muestra información de un usuario (estilo EmpresaCard)
class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleStatus;

  const UserCard({
    super.key,
    required this.user,
    this.onTap,
    this.onEdit,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = user['es_activo'] == 1;
    final tipoUsuario = user['tipo_usuario'] ?? '';
    final userColor = _getUserTypeColor(tipoUsuario);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.8)
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: userColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, userColor),
                  const SizedBox(height: 12),
                  _buildInfo(context),
                  const SizedBox(height: 12),
                  _buildTags(context, userColor, isActive),
                  const SizedBox(height: 12),
                  _buildActions(context, isActive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color userColor) {
    final nombre = user['nombre'] ?? 'Usuario';
    final apellido = user['apellido'] ?? '';

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: userColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$nombre $apellido',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                user['email'] ?? 'Sin email',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(context, user['es_activo'] == 1),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isActive) {
    final color = isActive ? AppColors.success : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Activo' : 'Inactivo',
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

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user['telefono'] != null && user['telefono'].toString().isNotEmpty)
          _buildInfoRow(context, Icons.phone_outlined, user['telefono']),
        if (user['fecha_registro'] != null)
          _buildInfoRow(context, Icons.calendar_today_outlined, 'Registrado: ${user['fecha_registro']}'),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context, Color userColor, bool isActive) {
    final tipoUsuario = user['tipo_usuario'] ?? '';
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: userColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getUserTypeIcon(tipoUsuario),
                size: 12,
                color: userColor,
              ),
              const SizedBox(width: 4),
              Text(
                _getUserTypeLabel(tipoUsuario),
                style: TextStyle(
                  color: userColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (user['es_verificado'] == 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 12, color: AppColors.success),
                SizedBox(width: 4),
                Text(
                  'Verificado',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, bool isActive) {
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.edit_outlined,
              label: 'Editar',
              color: AppColors.blue600,
              onTap: onEdit!,
            ),
          ),
        if (onEdit != null && onToggleStatus != null)
          const SizedBox(width: 8),
        if (onToggleStatus != null)
          Expanded(
            child: _buildActionButton(
              context,
              icon: isActive 
                  ? Icons.pause_circle_outline 
                  : Icons.play_circle_outline,
              label: isActive ? 'Desactivar' : 'Activar',
              color: isActive ? AppColors.warning : AppColors.success,
              onTap: onToggleStatus!,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(icon, size: 16, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
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
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  IconData _getUserTypeIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'administrador':
        return Icons.admin_panel_settings_rounded;
      case 'conductor':
        return Icons.local_taxi_rounded;
      case 'cliente':
        return Icons.person_rounded;
      case 'empresa':
        return Icons.business_rounded;
      default:
        return Icons.person_outline_rounded;
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

/// Sheet para ver detalles del usuario
class UserDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> user;

  const UserDetailsSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final tipoUsuario = user['tipo_usuario'] ?? '';
    final userColor = _getUserTypeColor(tipoUsuario);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: userColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    (user['nombre'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: userColor,
                      fontSize: 24,
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
                      '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: userColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getUserTypeLabel(tipoUsuario),
                        style: TextStyle(
                          color: userColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildDetailRow(context, Icons.email_outlined, 'Email', user['email'] ?? 'No disponible'),
          _buildDetailRow(context, Icons.phone_outlined, 'Teléfono', user['telefono'] ?? 'No disponible'),
          _buildDetailRow(
            context,
            Icons.verified_user_outlined,
            'Estado',
            (user['es_activo'] == 1) ? 'Activo' : 'Inactivo',
            valueColor: (user['es_activo'] == 1) ? AppColors.success : Colors.grey,
          ),
          _buildDetailRow(context, Icons.calendar_today_outlined, 'Registrado', user['fecha_registro'] ?? 'Desconocido'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
        return AppColors.warning;
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

/// Sheet para editar usuario
class UserEditSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String nombre, String apellido, String telefono, String tipoUsuario, int? empresaId, String? empresaNombre) onSave;

  const UserEditSheet({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<UserEditSheet> createState() => _UserEditSheetState();
}

class _UserEditSheetState extends State<UserEditSheet> {
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _telefonoController;
  late String _selectedRole;
  Map<String, dynamic>? _selectedCompany;
  int? _selectedEmpresaId;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.user['nombre']);
    _apellidoController = TextEditingController(text: widget.user['apellido']);
    _telefonoController = TextEditingController(text: widget.user['telefono']);
    _selectedRole = widget.user['tipo_usuario'] ?? 'cliente';
    _selectedEmpresaId = widget.user['empresa_id'] != null 
      ? int.tryParse(widget.user['empresa_id'].toString()) 
      : null;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Editar Usuario',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildTextField('Nombre', _nombreController),
            const SizedBox(height: 16),
            _buildTextField('Apellido', _apellidoController),
            const SizedBox(height: 16),
            _buildTextField('Teléfono', _telefonoController, keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            Text(
              'Rol del Usuario',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRoleOption('cliente', 'Cliente', Icons.person_rounded, const Color(0xFF11998e)),
                  const SizedBox(width: 8),
                  _buildRoleOption('conductor', 'Conductor', Icons.local_taxi_rounded, const Color(0xFF667eea)),
                  const SizedBox(width: 8),
                  _buildRoleOption('empresa', 'Empresa', Icons.business_rounded, AppColors.warning),
                  const SizedBox(width: 8),
                  _buildRoleOption('administrador', 'Admin', Icons.admin_panel_settings_rounded, const Color(0xFFf5576c)),
                ],
              ),
            ),
            
            // Company selector - shown when empresa or conductor is selected
            if (_selectedRole == 'empresa' || _selectedRole == 'conductor') ...[
              const SizedBox(height: 24),
              Text(
                'Empresa Asociada',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildCompanySelector(),
            ],
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  int? finalEmpresaId = _selectedEmpresaId;
                  String? finalEmpresaNombre = _selectedCompany?['nombre'];

                  // If role is NOT empresa/conductor, clear the company association
                  if (_selectedRole != 'empresa' && _selectedRole != 'conductor') {
                    finalEmpresaId = -1; // Sentinel value for "Clear"
                    finalEmpresaNombre = ''; 
                  } else if (_selectedEmpresaId == null) {
                      // If support role selected but no company picked, ensure cleared
                      finalEmpresaId = -1;
                  }

                  widget.onSave(
                    _nombreController.text,
                    _apellidoController.text,
                    _telefonoController.text,
                    _selectedRole,
                    finalEmpresaId,
                    finalEmpresaNombre,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.8)
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption(String value, String label, IconData icon, Color color) {
    final isSelected = _selectedRole == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCompany = _selectedCompany != null || _selectedEmpresaId != null;
    final companyName = _selectedCompany?['nombre'] ?? 
      widget.user['empresa_nombre'] ??
      (_selectedEmpresaId != null ? 'Empresa ID: $_selectedEmpresaId' : 'Sin empresa');
    
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CompanyPickerSheet(
            isDark: isDark,
            onSelected: (company) {
              setState(() {
                _selectedCompany = company;
                _selectedEmpresaId = company != null 
                  ? int.tryParse(company['id'].toString()) 
                  : null;
              });
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface.withValues(alpha: 0.8) : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCompany ? AppColors.primary.withValues(alpha: 0.5) : (isDark ? Colors.white12 : Colors.black12),
            width: hasCompany ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasCompany 
                  ? AppColors.primary.withValues(alpha: 0.1) 
                  : (isDark ? Colors.white12 : Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasCompany ? Icons.business_rounded : Icons.search_rounded,
                color: hasCompany ? AppColors.primary : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCompany ? companyName : 'Seleccionar Empresa',
                    style: TextStyle(
                      color: hasCompany 
                        ? Theme.of(context).textTheme.bodyLarge?.color 
                        : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      fontWeight: hasCompany ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (!hasCompany)
                    Text(
                      'Toca para buscar y vincular',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

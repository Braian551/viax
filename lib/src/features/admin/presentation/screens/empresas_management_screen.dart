import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/admin/data/models/empresa_transporte_model.dart';
import 'package:viax/src/features/admin/domain/entities/empresa_transporte.dart';
import 'package:viax/src/features/admin/presentation/providers/empresa_provider.dart';
import 'package:viax/src/features/admin/presentation/widgets/empresa_card.dart';
import 'package:viax/src/features/admin/presentation/widgets/empresa_commission_dialog.dart';
import 'package:viax/src/features/admin/presentation/widgets/empresa_form.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Pantalla de gestión de empresas de transporte
class EmpresasManagementScreen extends StatefulWidget {
  final Map<String, dynamic> adminUser;

  const EmpresasManagementScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<EmpresasManagementScreen> createState() => _EmpresasManagementScreenState();
}

class _EmpresasManagementScreenState extends State<EmpresasManagementScreen> {
  late EmpresaProvider _empresaProvider;
  final TextEditingController _searchController = TextEditingController();
  String? _estadoFilter;

  @override
  void initState() {
    super.initState();
    _empresaProvider = EmpresaProvider();
    _loadEmpresas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _empresaProvider.dispose();
    super.dispose();
  }

  void _loadEmpresas() {
    _empresaProvider.loadEmpresas(refresh: true);
  }

  int get _adminId => int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _empresaProvider,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(isDark),
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchAndFilters(isDark),
              Expanded(
                child: Consumer<EmpresaProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.empresas.isEmpty) {
                      return _buildLoadingState();
                    }

                    if (provider.hasError && provider.empresas.isEmpty) {
                      return _buildErrorState(provider.errorMessage ?? 'Error desconocido');
                    }

                    if (provider.empresas.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildEmpresasList(provider);
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.95)
                  : AppColors.lightSurface.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Empresas de Transporte',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Theme.of(context).textTheme.bodyLarge?.color,
          onPressed: _loadEmpresas,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barra de búsqueda
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.8)
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar empresa...',
                hintStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _empresaProvider.setFilters(search: null);
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (value) {
                _empresaProvider.setFilters(search: value.isEmpty ? null : value);
              },
            ),
          ),
          const SizedBox(height: 12),
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Todas',
                  isSelected: _estadoFilter == null,
                  onTap: () {
                    setState(() => _estadoFilter = null);
                    _empresaProvider.setFilters(estado: null);
                  },
                ),
                _buildFilterChip(
                  label: 'Activas',
                  isSelected: _estadoFilter == 'activo',
                  color: AppColors.success,
                  onTap: () {
                    setState(() => _estadoFilter = 'activo');
                    _empresaProvider.setFilters(estado: 'activo');
                  },
                ),
                _buildFilterChip(
                  label: 'Pendientes',
                  isSelected: _estadoFilter == 'pendiente',
                  color: AppColors.warning,
                  onTap: () {
                    setState(() => _estadoFilter = 'pendiente');
                    _empresaProvider.setFilters(estado: 'pendiente');
                  },
                ),
                _buildFilterChip(
                  label: 'Inactivas',
                  isSelected: _estadoFilter == 'inactivo',
                  color: Colors.grey,
                  onTap: () {
                    setState(() => _estadoFilter = 'inactivo');
                    _empresaProvider.setFilters(estado: 'inactivo');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final chipColor = color ?? AppColors.primary;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? chipColor
                  : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpresasList(EmpresaProvider provider) {
    return RefreshIndicator(
      onRefresh: () async => _loadEmpresas(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: provider.empresas.length,
        itemBuilder: (context, index) {
          final empresa = provider.empresas[index];
          return EmpresaCard(
            empresa: empresa,
            onTap: () => _showEmpresaDetails(empresa),
            onEdit: () => _showEditEmpresaSheet(empresa),
            onDelete: () => _confirmDeleteEmpresa(empresa),
            onToggleStatus: () => _toggleEmpresaStatus(empresa),
            onSetCommission: () => _showCommissionDialog(empresa),
            onApprove: empresa.estado == EmpresaEstado.pendiente 
                ? () => _approveEmpresa(empresa) 
                : null,
            onReject: empresa.estado == EmpresaEstado.pendiente 
                ? () => _showRejectDialog(empresa) 
                : null,
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar empresas',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEmpresas,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_outlined,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay empresas registradas',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra la primera empresa de transporte\npara comenzar',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateEmpresaSheet,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Registrar Empresa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showCreateEmpresaSheet,
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add_business_rounded, color: Colors.white),
      label: const Text(
        'Nueva Empresa',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showCreateEmpresaSheet() {
    _showEmpresaFormSheet(null);
  }

  void _showEditEmpresaSheet(EmpresaTransporte empresa) {
    _showEmpresaFormSheet(empresa);
  }

  void _showEmpresaFormSheet(EmpresaTransporte? empresa) {
    final isEditing = empresa != null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool isLoading = false;
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_business_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEditing ? 'Editar Empresa' : 'Nueva Empresa',
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
                  ),
                  const Divider(height: 1),
                  // Form
                  Expanded(
                    child: EmpresaForm(
                      empresa: empresa,
                      isLoading: isLoading,
                      onCancel: () => Navigator.pop(context),
                      onSubmit: (formData) async {
                        setSheetState(() => isLoading = true);
                        
                        bool success;
                        if (isEditing) {
                          success = await _empresaProvider.updateEmpresa(
                            empresa.id,
                            formData,
                            _adminId,
                          );
                        } else {
                          final empresaId = await _empresaProvider.createEmpresa(
                            formData,
                            _adminId,
                          );
                          success = empresaId != null;
                        }
                        
                        setSheetState(() => isLoading = false);
                        
                        if (success && mounted) {
                          Navigator.pop(context);
                          _showSnackBar(
                            isEditing
                                ? 'Empresa actualizada exitosamente'
                                : 'Empresa creada exitosamente',
                            isSuccess: true,
                          );
                        } else if (mounted) {
                          _showSnackBar(
                            _empresaProvider.errorMessage ?? 'Error al guardar',
                            isSuccess: false,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEmpresaDetails(EmpresaTransporte empresa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            empresa.nombre,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (empresa.nit != null)
                            Text(
                              'NIT: ${empresa.nit}',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                fontSize: 14,
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
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection(
                        context,
                        'Información de Contacto',
                        [
                          if (empresa.email != null)
                            _buildDetailRow(context, 'Email', empresa.email!),
                          if (empresa.telefono != null)
                            _buildDetailRow(context, 'Teléfono', empresa.telefono!),
                          if (empresa.direccion != null)
                            _buildDetailRow(context, 'Dirección', empresa.direccion!),
                          if (empresa.municipio != null || empresa.departamento != null)
                            _buildDetailRow(
                              context,
                              'Ubicación',
                              [empresa.municipio, empresa.departamento]
                                  .where((e) => e != null)
                                  .join(', '),
                            ),
                        ],
                      ),
                      if (empresa.representanteNombre != null) ...[
                        const SizedBox(height: 20),
                        _buildDetailSection(
                          context,
                          'Representante Legal',
                          [
                            _buildDetailRow(context, 'Nombre', empresa.representanteNombre!),
                            if (empresa.representanteTelefono != null)
                              _buildDetailRow(context, 'Teléfono', empresa.representanteTelefono!),
                            if (empresa.representanteEmail != null)
                              _buildDetailRow(context, 'Email', empresa.representanteEmail!),
                          ],
                        ),
                      ],
                      if (empresa.descripcion != null) ...[
                        const SizedBox(height: 20),
                        _buildDetailSection(
                          context,
                          'Descripción',
                          [_buildDetailRow(context, '', empresa.descripcion!)],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ],
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEmpresa(EmpresaTransporte empresa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar Empresa'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${empresa.nombre}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _empresaProvider.deleteEmpresa(empresa.id, _adminId);
              if (mounted) {
                _showSnackBar(
                  success ? 'Empresa eliminada' : (_empresaProvider.errorMessage ?? 'Error al eliminar'),
                  isSuccess: success,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _toggleEmpresaStatus(EmpresaTransporte empresa) async {
    final nuevoEstado = empresa.estado == EmpresaEstado.activo ? 'inactivo' : 'activo';
    final success = await _empresaProvider.toggleEmpresaStatus(empresa.id, nuevoEstado, _adminId);
    
    if (mounted) {
      _showSnackBar(
        success
            ? 'Estado cambiado a ${nuevoEstado == 'activo' ? 'Activo' : 'Inactivo'}'
            : (_empresaProvider.errorMessage ?? 'Error al cambiar estado'),
        isSuccess: success,
      );
    }
  }

  void _approveEmpresa(EmpresaTransporte empresa) async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Aprobar Empresa'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Deseas aprobar el registro de "${empresa.nombre}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La empresa recibirá un email de confirmación y podrá comenzar a operar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Aprobar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _empresaProvider.approveEmpresa(empresa.id, _adminId);
      if (mounted) {
        _showSnackBar(
          success
              ? 'Empresa "${empresa.nombre}" aprobada exitosamente'
              : (_empresaProvider.errorMessage ?? 'Error al aprobar empresa'),
          isSuccess: success,
        );
      }
    }
  }

  void _showRejectDialog(EmpresaTransporte empresa) async {
    final motivoController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Rechazar Empresa'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Deseas rechazar el registro de "${empresa.nombre}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo del rechazo *',
                hintText: 'Indica el motivo por el cual se rechaza el registro...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La empresa recibirá un email con el motivo del rechazo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (motivoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Debes indicar el motivo del rechazo'),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
                return;
              }
              Navigator.pop(context, motivoController.text.trim());
            },
            icon: const Icon(Icons.cancel_rounded, size: 18),
            label: const Text('Rechazar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _empresaProvider.rejectEmpresa(empresa.id, _adminId, result);
      if (mounted) {
        _showSnackBar(
          success
              ? 'Empresa "${empresa.nombre}" rechazada'
              : (_empresaProvider.errorMessage ?? 'Error al rechazar empresa'),
          isSuccess: success,
        );
      }
    }
  }

  void _showCommissionDialog(EmpresaTransporte empresa) async {
    final empresaMap = {
      'id': empresa.id,
      'nombre': empresa.nombre,
      'comision_admin_porcentaje': 0.0, // Will be fetched by the dialog
    };
    
    final result = await EmpresaCommissionDialog.show(context, empresaMap);
    
    if (result == true && mounted) {
      _loadEmpresas(); // Refresh list after commission update
    }
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

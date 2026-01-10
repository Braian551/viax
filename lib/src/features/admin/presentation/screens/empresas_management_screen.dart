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
import 'package:viax/src/core/config/app_config.dart';

import 'package:viax/src/features/admin/presentation/widgets/empresa_card_shimmer.dart';

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
  final Set<int> _processingEmpresas = {};

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
            isLoading: _processingEmpresas.contains(empresa.id),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return const EmpresaCardShimmer();
      },
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
          builder: (context, _) {
            
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
                      onCancel: () => Navigator.pop(context),
                      onSubmit: (formData) async {
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle area
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              
              // Sticky Header with Close button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detalles de Empresa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Header Section (Logo + Name + Status)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            // Large Logo
                            Hero(
                              tag: 'empresa_logo_${empresa.id}',
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: empresa.logoUrl != null && empresa.logoUrl!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Image.network(
                                          empresa.logoUrl!.startsWith('http') 
                                              ? empresa.logoUrl!
                                              : '${AppConfig.baseUrl}/${empresa.logoUrl!}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.business_rounded,
                                            color: AppColors.primary,
                                            size: 48,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.business_rounded,
                                        color: AppColors.primary,
                                        size: 48,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Name
                            Text(
                              empresa.nombre,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            // NIT & Verification Badge
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (empresa.nit != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'NIT: ${empresa.nit}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                if (empresa.verificada) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Verificada',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Status Chips
                            _buildInfoChip(
                              context, 
                              label: empresa.estado.displayName, 
                              color: _getStatusColor(empresa.estado),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 2. Overview Stats (Row)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.people_alt_outlined,
                              value: '${empresa.totalConductores}',
                              label: 'Conductores',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.route_outlined,
                              value: '${empresa.totalViajesCompletados}',
                              label: 'Viajes',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.star_rounded,
                              value: empresa.calificacionPromedio.toStringAsFixed(1),
                              label: 'Calificación',
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 3. Contact Info Section
                      _buildSectionTitle(context, 'Contacto y Ubicación'),
                      const SizedBox(height: 12),
                      _buildModernInfoCard(
                        context,
                        children: [
                          if (empresa.email != null)
                            _buildModernRow(context, Icons.email_rounded, 'Email', empresa.email!, hasDivider: true),
                          if (empresa.telefono != null)
                            _buildModernRow(context, Icons.phone_rounded, 'Teléfono', empresa.telefono!, hasDivider: true),
                          if (empresa.municipio != null || empresa.departamento != null)
                             _buildModernRow(
                              context, 
                              Icons.location_on_rounded, 
                              'Ubicación', 
                              [empresa.municipio, empresa.departamento].where((e) => e != null).join(', '), 
                              hasDivider: empresa.direccion != null
                            ),
                          if (empresa.direccion != null)
                            _buildModernRow(context, Icons.map_rounded, 'Dirección', empresa.direccion!, hasDivider: false),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // 4. Representative Section
                      if (empresa.representanteNombre != null) ...[
                        _buildSectionTitle(context, 'Representante Legal'),
                        const SizedBox(height: 12),
                        _buildModernInfoCard(
                          context,
                          children: [
                            _buildModernRow(
                              context, 
                              Icons.person_rounded, 
                              'Nombre', 
                              empresa.representanteNombre!, 
                              hasDivider: empresa.representanteTelefono != null || empresa.representanteEmail != null
                            ),
                            if (empresa.representanteTelefono != null)
                              _buildModernRow(
                                context, 
                                Icons.phone_iphone_rounded, 
                                'Móvil', 
                                empresa.representanteTelefono!, 
                                hasDivider: empresa.representanteEmail != null
                              ),
                            if (empresa.representanteEmail != null)
                              _buildModernRow(
                                context, 
                                Icons.alternate_email_rounded, 
                                'Email Personal', 
                                empresa.representanteEmail!, 
                                hasDivider: false
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 5. Vehicle Types Section
                      if (empresa.tiposVehiculo.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Flota Permitida'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: empresa.tiposVehiculo.map((tipo) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getVehicleIcon(tipo),
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tipo[0].toUpperCase() + tipo.substring(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // 6. Description
                      if (empresa.descripcion != null && empresa.descripcion!.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Descripción'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF252525) : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            empresa.descripcion!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
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

  // --- Helper Widgets for New UI ---

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.bodyLarge?.color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildModernRow(
    BuildContext context, 
    IconData icon, 
    String label, 
    String value, 
    {bool hasDivider = true}
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
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
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasDivider)
          Divider(
            height: 1, 
            thickness: 1, 
            indent: 60,
            endIndent: 20,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
      ],
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
              
              setState(() => _processingEmpresas.add(empresa.id));
              final success = await _empresaProvider.deleteEmpresa(empresa.id, _adminId);
              
              if (mounted) {
                setState(() => _processingEmpresas.remove(empresa.id));
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
    setState(() => _processingEmpresas.add(empresa.id));
    
    final nuevoEstado = empresa.estado == EmpresaEstado.activo ? 'inactivo' : 'activo';
    final success = await _empresaProvider.toggleEmpresaStatus(empresa.id, nuevoEstado, _adminId);
    
    if (mounted) {
      setState(() => _processingEmpresas.remove(empresa.id));
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
      setState(() => _processingEmpresas.add(empresa.id));
      
      final success = await _empresaProvider.approveEmpresa(empresa.id, _adminId);
      
      if (mounted) {
        setState(() => _processingEmpresas.remove(empresa.id));
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
      setState(() => _processingEmpresas.add(empresa.id));
      
      final success = await _empresaProvider.rejectEmpresa(empresa.id, _adminId, result);
      
      if (mounted) {
        setState(() => _processingEmpresas.remove(empresa.id));
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

  Color _getStatusColor(EmpresaEstado estado) {
    switch (estado) {
      case EmpresaEstado.activo:
        return AppColors.success;
      case EmpresaEstado.inactivo:
        return Colors.grey;
      case EmpresaEstado.suspendido:
        return AppColors.error;
      case EmpresaEstado.pendiente:
        return AppColors.warning;
      case EmpresaEstado.eliminado:
        return AppColors.error;
    }
  }

  IconData _getVehicleIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'moto':
        return Icons.two_wheeler;
      case 'motocarro':
        return Icons.electric_rickshaw;
      case 'taxi':
        return Icons.local_taxi;
      case 'carro':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../../../theme/app_colors.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../data/repositories/admin_user_repository_impl.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/manage_user_usecase.dart';
import '../providers/user_management_provider.dart';
import '../widgets/user_management_widgets.dart';

/// Pantalla de gestión de usuarios
class UsersManagementScreen extends StatefulWidget {
  final int adminId;
  final Map<String, dynamic> adminUser;

  const UsersManagementScreen({
    super.key,
    required this.adminId,
    required this.adminUser,
  });

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  late AdminUserManagementProvider _provider;
  final TextEditingController _searchController = TextEditingController();
  String? _tipoFilter;

  @override
  void initState() {
    super.initState();
    final client = http.Client();
    final remoteDataSource = AdminRemoteDataSourceImpl(client: client);
    final repository = AdminUserRepositoryImpl(remoteDataSource: remoteDataSource);
    final getUsersUseCase = GetUsersUseCase(repository);
    final manageUserUseCase = ManageUserUseCase(repository);
    
    _provider = AdminUserManagementProvider(
      getUsersUseCase: getUsersUseCase,
      manageUserUseCase: manageUserUseCase,
      adminId: widget.adminId,
    )..loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(isDark),
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchAndFilters(isDark),
              Expanded(
                child: Consumer<AdminUserManagementProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.users.isEmpty) {
                      return _buildLoadingState();
                    }

                    if (provider.users.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildUsersList(provider);
                  },
                ),
              ),
            ],
          ),
        ),
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
              Icons.people_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Gestión de Usuarios',
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
          onPressed: () => _provider.loadUsers(refresh: true),
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
                hintText: 'Buscar por nombre, email o teléfono...',
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
                          _provider.setSearchQuery('');
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
                _provider.setSearchQuery(value);
              },
              onChanged: (value) {
                setState(() {}); // Update clear button visibility
              },
            ),
          ),
          const SizedBox(height: 12),
          // Filtros de tipo
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Todos',
                        isSelected: _tipoFilter == null,
                        onTap: () {
                          setState(() => _tipoFilter = null);
                          _provider.setFilter(null);
                        },
                      ),
                      _buildFilterChip(
                        label: 'Clientes',
                        isSelected: _tipoFilter == 'cliente',
                        color: const Color(0xFF11998e),
                        onTap: () {
                          setState(() => _tipoFilter = 'cliente');
                          _provider.setFilter('cliente');
                        },
                      ),
                      _buildFilterChip(
                        label: 'Conductores',
                        isSelected: _tipoFilter == 'conductor',
                        color: const Color(0xFF667eea),
                        onTap: () {
                          setState(() => _tipoFilter = 'conductor');
                          _provider.setFilter('conductor');
                        },
                      ),
                      _buildFilterChip(
                        label: 'Empresas',
                        isSelected: _tipoFilter == 'empresa',
                        color: AppColors.warning,
                        onTap: () {
                          setState(() => _tipoFilter = 'empresa');
                          _provider.setFilter('empresa');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Toggle for Activos/Inactivos
              GestureDetector(
                onTap: () {
                  _provider.setShowInactive(!_provider.showInactive);
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _provider.showInactive 
                        ? Colors.red.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _provider.showInactive ? Colors.red : AppColors.success,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _provider.showInactive 
                            ? Icons.person_off_rounded 
                            : Icons.person_rounded,
                        size: 16,
                        color: _provider.showInactive ? Colors.red : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _provider.showInactive ? 'Inactivos' : 'Activos',
                        style: TextStyle(
                          color: _provider.showInactive ? Colors.red : AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

  Widget _buildUsersList(AdminUserManagementProvider provider) {
    return RefreshIndicator(
      onRefresh: () async => provider.loadUsers(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: provider.users.length,
        itemBuilder: (context, index) {
          final user = provider.users[index];
          return UserCard(
            user: user,
            onTap: () => _showUserDetails(context, user),
            onEdit: () => _showUserEdit(context, provider, user),
            onToggleStatus: () => _showStatusConfirmation(context, provider, user),
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
                Icons.people_outline_rounded,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay usuarios',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron usuarios con los filtros actuales',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserDetailsSheet(user: user),
    );
  }

  void _showUserEdit(BuildContext context, AdminUserManagementProvider provider, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserEditSheet(
        user: user,
        onSave: (nombre, apellido, telefono, tipoUsuario) async {
          final success = await provider.updateUser(
            userId: user['id'],
            nombre: nombre,
            apellido: apellido,
            telefono: telefono,
            tipoUsuario: tipoUsuario,
          );
          
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'Usuario actualizado correctamente' : 'Error al actualizar usuario'),
                backgroundColor: success ? AppColors.success : AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _showStatusConfirmation(BuildContext context, AdminUserManagementProvider provider, Map<String, dynamic> user) {
    final isActivating = user['es_activo'] == 0;
    final action = isActivating ? 'activar' : 'desactivar';
    final color = isActivating ? AppColors.success : AppColors.warning;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActivating ? Icons.play_circle_outline : Icons.pause_circle_outline,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Text('${action[0].toUpperCase()}${action.substring(1)} Usuario'),
          ],
        ),
        content: Text('¿Estás seguro de que deseas $action a "${user['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.toggleUserStatus(user['id'], !isActivating);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(isActivating ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
  }
}

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

class UsersManagementScreen extends StatelessWidget {
  final int adminId;
  final Map<String, dynamic> adminUser;

  const UsersManagementScreen({
    Key? key,
    required this.adminId,
    required this.adminUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dependency Injection Setup (Local for this feature)
    // In a larger app, use GetIt or global Providers
    final client = http.Client();
    final remoteDataSource = AdminRemoteDataSourceImpl(client: client);
    final repository = AdminUserRepositoryImpl(remoteDataSource: remoteDataSource);
    final getUsersUseCase = GetUsersUseCase(repository);
    final manageUserUseCase = ManageUserUseCase(repository);

    return ChangeNotifierProvider(
      create: (_) => AdminUserManagementProvider(
        getUsersUseCase: getUsersUseCase,
        manageUserUseCase: manageUserUseCase,
      )..loadUsers(),
      child: const _UsersManagementContent(),
    );
  }
}

class _UsersManagementContent extends StatefulWidget {
  const _UsersManagementContent({Key? key}) : super(key: key);

  @override
  State<_UsersManagementContent> createState() => _UsersManagementContentState();
}

class _UsersManagementContentState extends State<_UsersManagementContent> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminUserManagementProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, provider),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, provider),
            Expanded(
              child: provider.isLoading && provider.users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildUserList(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AdminUserManagementProvider provider) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Gestión de Usuarios',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: () => provider.loadUsers(refresh: true),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AdminUserManagementProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserSearchField(
            controller: _searchController,
            onChanged: (value) => provider.setSearchQuery(value),
            onClear: () {
              _searchController.clear();
              provider.setSearchQuery('');
            },
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                UserFilterTab(
                  label: 'Todos',
                  value: null,
                  icon: Icons.people_rounded,
                  isSelected: provider.currentFilter == null,
                  onTap: () => provider.setFilter(null),
                ),
                const SizedBox(width: 8),
                UserFilterTab(
                  label: 'Clientes',
                  value: 'cliente',
                  icon: Icons.person_rounded,
                  isSelected: provider.currentFilter == 'cliente',
                  onTap: () => provider.setFilter('cliente'),
                ),
                const SizedBox(width: 8),
                UserFilterTab(
                  label: 'Conductores',
                  value: 'conductor',
                  icon: Icons.local_taxi_rounded,
                  isSelected: provider.currentFilter == 'conductor',
                  onTap: () => provider.setFilter('conductor'),
                ),
                const SizedBox(width: 8),
                UserFilterTab(
                  label: 'Empresas',
                  value: 'empresa',
                  icon: Icons.business_rounded,
                  isSelected: provider.currentFilter == 'empresa',
                  onTap: () => provider.setFilter('empresa'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${provider.users.length} usuarios encontrados',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(BuildContext context, AdminUserManagementProvider provider) {
    if (provider.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No se encontraron usuarios',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: provider.users.length,
        itemBuilder: (context, index) {
          final user = provider.users[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: UserListCard(
              user: user,
              onTap: () {
                // TODO: Navigate to details
              },
              onAction: (action) {
                if (action == 'activate' || action == 'deactivate') {
                  provider.toggleUserStatus(user['id'], user['es_activo'] == 1);
                }
                // Handle other actions
              },
            ),
          );
        },
      ),
    );
  }
}

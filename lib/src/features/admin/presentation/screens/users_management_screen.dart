// lib/src/features/admin/presentation/screens/users_management_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/theme/app_colors.dart';

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

class _UsersManagementScreenState extends State<UsersManagementScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _selectedFilter;
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUsers();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      print('UsersManagement: Cargando usuarios para adminId: ${widget.adminId}');
      print('UsersManagement: Filtro: $_selectedFilter, BÃºsqueda: ${_searchController.text}');
      
      final response = await AdminService.getUsers(
        adminId: widget.adminId,
        tipoUsuario: _selectedFilter,
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );

      print('UsersManagement: Response: $response');

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _users = response['data']['usuarios'] ?? [];
          _isLoading = false;
        });
        _animationController.forward(from: 0);
        
        if (_users.isEmpty) {
          CustomSnackbar.showInfo(context, message: 'No se encontraron usuarios');
        }
      } else {
        final errorMsg = response['message'] ?? 'Error al cargar usuarios';
        CustomSnackbar.showError(context, message: errorMsg);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('UsersManagement Error: $e');
      CustomSnackbar.showError(context, message: 'Error de conexiÃ³n: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: _isLoading ? _buildShimmerLoading() : _buildContent(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF667eea).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFF667eea).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.people_rounded,
              color: Color(0xFF667eea),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gestión de Usuarios',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Administrar sistema',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
            ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 22),
            onPressed: _loadUsers,
            tooltip: 'Actualizar',
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildShimmerBox(height: 56),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildShimmerBox(height: 40, width: 80),
                const SizedBox(width: 8),
                _buildShimmerBox(height: 40, width: 100),
                const SizedBox(width: 8),
                _buildShimmerBox(height: 40, width: 120),
              ],
            ),
            const SizedBox(height: 24),
            _buildShimmerBox(height: 24, width: 150),
            const SizedBox(height: 16),
            Column(
              children: List.generate(
                5,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildShimmerBox(height: 100, width: double.infinity),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({required double height, double? width}) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
      highlightColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          onRefresh: _loadUsers,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFilterChips(),
                  const SizedBox(height: 24),
                  _buildUsersHeader(),
                  const SizedBox(height: 16),
                  _users.isEmpty ? _buildEmptyState() : _buildUsersList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
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
            controller: _searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, email o teléfono...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _loadUsers();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onChanged: (value) {
              if (value.isEmpty || value.length >= 2) {
                _loadUsers();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Todos', null, Icons.people_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Clientes', 'cliente', Icons.person_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Conductores', 'conductor', Icons.local_taxi_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Admins', 'administrador', Icons.admin_panel_settings_rounded),
        ],
      ),
    );
  }

  Widget _buildUsersHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usuarios registrados',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_users.length} usuario${_users.length != 1 ? 's' : ''} encontrado${_users.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF667eea).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Text(
            '${_users.length}',
            style: const TextStyle(
              color: Color(0xFF667eea),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No se encontraron usuarios',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Intenta cambiar los filtros de búsqueda',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    return Column(
      children: _users.map((user) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildUserCard(user),
      )).toList(),
    );
  }

  Widget _buildFilterChip(String label, String? value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadUsers();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
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
              onTap: () => _showUserDetails(user),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: userColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: userColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          nombre[0].toUpperCase(),
                          style: TextStyle(
                            color: userColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
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
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user['email'] ?? 'Sin email',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Tipo de usuario
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: userColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: userColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getUserTypeIcon(tipoUsuario),
                                      color: userColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getUserTypeLabel(tipoUsuario),
                                      style: TextStyle(
                                        color: userColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Estado
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: isActive 
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive 
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.red.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.green : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isActive ? 'Activo' : 'Inactivo',
                                      style: TextStyle(
                                        color: isActive ? Colors.green : Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Menu button
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          size: 22,
                        ),
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF667eea),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Ver detalles',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Editar',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: isActive ? 'deactivate' : 'activate',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isActive
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                                    color: isActive ? Colors.red : Colors.green,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isActive ? 'Desactivar' : 'Activar',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) => _handleUserAction(value, user),
                      ),
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

  Color _getUserTypeColor(String tipo) {
    switch (tipo) {
      case 'administrador':
        return const Color(0xFFf5576c);
      case 'conductor':
        return const Color(0xFF667eea);
      case 'cliente':
        return const Color(0xFF11998e);
      default:
        return Colors.grey;
    }
  }

  IconData _getUserTypeIcon(String tipo) {
    switch (tipo) {
      case 'administrador':
        return Icons.admin_panel_settings_rounded;
      case 'conductor':
        return Icons.local_taxi_rounded;
      case 'cliente':
        return Icons.person_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getUserTypeLabel(String tipo) {
    switch (tipo) {
      case 'administrador':
        return 'Admin';
      case 'conductor':
        return 'Conductor';
      case 'cliente':
        return 'Cliente';
      default:
        return tipo;
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detalles del usuario',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Nombre', '${user['nombre']} ${user['apellido']}'),
                _buildDetailRow('Email', user['email']),
                _buildDetailRow('Teléfono', user['telefono']),
                _buildDetailRow('Tipo', user['tipo_usuario']),
                _buildDetailRow('Estado', user['es_activo'] == 1 ? 'Activo' : 'Inactivo'),
                _buildDetailRow('Verificado', user['es_verificado'] == 1 ? 'Sí' : 'No'),
                _buildDetailRow('Registro', user['fecha_registro'] ?? 'N/A'),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleUserAction(dynamic action, Map<String, dynamic> user) async {
    final userId = int.tryParse(user['id']?.toString() ?? '0') ?? 0;

    if (action == 'details') {
      _showUserDetails(user);
    } else if (action == 'edit') {
      _showEditUserDialog(user);
    } else if (action == 'deactivate' || action == 'activate') {
      final newState = action == 'activate';
      final response = await AdminService.updateUser(
        adminId: widget.adminId,
        userId: userId,
        esActivo: newState,
      );

      if (response['success'] == true) {
        CustomSnackbar.showSuccess(
          context,
          message: newState ? 'Usuario activado' : 'Usuario desactivado',
        );
        _loadUsers();
      } else {
        final errorMsg = response['message'] ?? 'Error al actualizar usuario';
        CustomSnackbar.showError(context, message: errorMsg);
      }
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final userId = int.tryParse(user['id']?.toString() ?? '0') ?? 0;
    final nombreController = TextEditingController(text: user['nombre'] ?? '');
    final apellidoController = TextEditingController(text: user['apellido'] ?? '');
    final telefonoController = TextEditingController(text: user['telefono'] ?? '');
    
    String selectedTipoUsuario = user['tipo_usuario'] ?? 'cliente';
    bool isActive = user['es_activo'] == 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Editar Usuario',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Nombre
                    _buildEditTextField(
                      controller: nombreController,
                      label: 'Nombre',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 16),
                    
                    // Apellido
                    _buildEditTextField(
                      controller: apellidoController,
                      label: 'Apellido',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    
                    // Teléfono
                    _buildEditTextField(
                      controller: telefonoController,
                      label: 'Teléfono',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    
                    // Tipo de usuario
                    Text(
                      'Tipo de usuario',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTipoUsuario,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'cliente',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    color: const Color(0xFF11998e),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Cliente'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'conductor',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_taxi_rounded,
                                    color: const Color(0xFF667eea),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Conductor'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'administrador',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: const Color(0xFFf5576c),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Administrador'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                selectedTipoUsuario = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Estado activo
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Usuario activo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isActive ? 'El usuario puede iniciar sesión' : 'El usuario no puede iniciar sesión',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        value: isActive,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) {
                          setModalState(() {
                            isActive = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFFFFD700)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton(
                              onPressed: () async {
                                // Validaciones
                                if (nombreController.text.trim().isEmpty) {
                                  CustomSnackbar.showError(context, message: 'El nombre es requerido');
                                  return;
                                }
                                if (apellidoController.text.trim().isEmpty) {
                                  CustomSnackbar.showError(context, message: 'El apellido es requerido');
                                  return;
                                }
                                if (telefonoController.text.trim().isEmpty) {
                                  CustomSnackbar.showError(context, message: 'El teléfono es requerido');
                                  return;
                                }

                                // Actualizar usuario
                                final response = await AdminService.updateUser(
                                  adminId: widget.adminId,
                                  userId: userId,
                                  nombre: nombreController.text.trim(),
                                  apellido: apellidoController.text.trim(),
                                  telefono: telefonoController.text.trim(),
                                  tipoUsuario: selectedTipoUsuario,
                                  esActivo: isActive,
                                );

                                if (response['success'] == true) {
                                  Navigator.pop(context);
                                  CustomSnackbar.showSuccess(
                                    context,
                                    message: 'Usuario actualizado exitosamente',
                                  );
                                  _loadUsers();
                                } else {
                                  final errorMsg = response['message'] ?? 'Error al actualizar usuario';
                                  CustomSnackbar.showError(context, message: errorMsg);
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Guardar',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
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
    ).then((_) {
      // Limpiar controllers
      nombreController.dispose();
      apellidoController.dispose();
      telefonoController.dispose();
    });
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: AppColors.primary,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}





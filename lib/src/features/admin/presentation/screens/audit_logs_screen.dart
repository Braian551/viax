// lib/src/features/admin/presentation/screens/audit_logs_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

class AuditLogsScreen extends StatefulWidget {
  final int adminId;

  const AuditLogsScreen({
    super.key,
    required this.adminId,
  });

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  int _currentPage = 1;
  String? _selectedFilter;
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadLogs();
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

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    
    final response = await AdminService.getAuditLogs(
      adminId: widget.adminId,
      page: _currentPage,
      perPage: 50,
    );
    
    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _logs = response['data']['logs'] ?? [];
        _isLoading = false;
      });
      _animationController.forward(from: 0);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
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
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logs de Auditoría',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Historial de actividades',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
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
            color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF667eea)),
            onPressed: _loadLogs,
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
            _buildShimmerBox(height: 50),
            const SizedBox(height: 16),
            _buildShimmerBox(height: 60),
            const SizedBox(height: 20),
            ...List.generate(8, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildShimmerBox(height: 120),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({required double height, double? width}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
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
          color: const Color(0xFF667eea),
          backgroundColor: const Color(0xFF1A1A1A),
          onRefresh: _loadLogs,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFilterChips(),
                  const SizedBox(height: 20),
                  _buildLogsHeader(),
                  const SizedBox(height: 16),
                  _logs.isEmpty ? _buildEmptyState() : _buildLogsList(),
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
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1)),
            ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar logs...',
              hintStyle: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search_rounded, color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.5)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.white60,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _loadLogs();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onSubmitted: (_) => _loadLogs(),
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
          _buildFilterChip('Todos', null, Icons.all_inclusive_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Login', 'login', Icons.login_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Crear', 'crear', Icons.add_circle_outline_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Actualizar', 'actualizar', Icons.edit_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Eliminar', 'eliminar', Icons.delete_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadLogs();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF667eea).withValues(alpha: 0.3)
                  : const Color(0xFF1A1A1A).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? const Color(0xFF667eea)
                  : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF667eea) : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF667eea) : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividades recientes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sistema de auditoría',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF667eea).withValues(alpha: 0.3),
              ),
            ),
          child: Text(
            '${_logs.length} registros',
            style: TextStyle(
              color: Color(0xFF667eea),
              fontSize: 13,
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
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1)),
            ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: Colors.white30,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay logs disponibles',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los registros de actividad aparecerán aquí',
                style: TextStyle(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    return Column(
      children: _logs.map((log) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildLogCard(log),
      )).toList(),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final accion = log['accion'] ?? '';
    final descripcion = log['descripcion'] ?? '';
    final usuario = '${log['nombre'] ?? ''} ${log['apellido'] ?? ''}'.trim();
    final email = log['email'] ?? '';
    final fecha = _formatDate(log['fecha_creacion']);
    final actionColor = _getActionColor(accion);
    final actionIcon = _getActionIcon(accion);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1)),
            ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showLogDetails(log),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            actionIcon,
                            color: actionColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      accion.toUpperCase(),
                                      style: TextStyle(
                                        color: actionColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      fecha,
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                descripcion,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (usuario.isNotEmpty || email.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.05)),
                          ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF667eea).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: Color(0xFF667eea),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (usuario.isNotEmpty)
                                    Text(
                                      usuario,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.3),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getActionColor(String accion) {
    final lower = accion.toLowerCase();
    if (lower.contains('login') || lower.contains('acceso')) return const Color(0xFF11998e);
    if (lower.contains('crear') || lower.contains('registro')) return const Color(0xFF667eea);
    if (lower.contains('actualizar') || lower.contains('editar')) return AppColors.primary;
    if (lower.contains('eliminar') || lower.contains('desactivar')) return const Color(0xFFf5576c);
    return const Color(0xFF667eea);
  }

  IconData _getActionIcon(String accion) {
    final lower = accion.toLowerCase();
    if (lower.contains('login') || lower.contains('acceso')) return Icons.login_rounded;
    if (lower.contains('crear') || lower.contains('registro')) return Icons.add_circle_rounded;
    if (lower.contains('actualizar') || lower.contains('editar')) return Icons.edit_rounded;
    if (lower.contains('eliminar') || lower.contains('desactivar')) return Icons.delete_rounded;
    return Icons.info_rounded;
  }

  void _showLogDetails(Map<String, dynamic> log) {
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
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getActionColor(log['accion'] ?? '').withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getActionIcon(log['accion'] ?? ''),
                        color: _getActionColor(log['accion'] ?? ''),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Detalles del Log',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white60,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Acción', log['accion']),
                _buildDetailRow('Descripción', log['descripcion']),
                _buildDetailRow('Usuario', '${log['nombre'] ?? ''} ${log['apellido'] ?? ''}'.trim()),
                _buildDetailRow('Email', log['email']),
                _buildDetailRow('IP', log['ip_address']),
                _buildDetailRow('User Agent', log['user_agent']),
                _buildDetailRow('Fecha', _formatFullDate(log['fecha_creacion'])),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white).withValues(alpha: 0.1)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Ahora';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
      
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatFullDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}





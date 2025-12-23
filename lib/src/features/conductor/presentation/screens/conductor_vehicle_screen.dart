import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/vehicle/vehicle_widgets.dart';

/// Pantalla Mi Vehículo del Conductor
/// 
/// Muestra la información del vehículo registrado con opciones
/// para ver detalles, estado de verificación y editar.
class ConductorVehicleScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;

  const ConductorVehicleScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
  });

  @override
  State<ConductorVehicleScreen> createState() => _ConductorVehicleScreenState();
}

class _ConductorVehicleScreenState extends State<ConductorVehicleScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Map<String, dynamic>? _vehicleData;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVehicleData();
    });
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Simular carga - En producción usar el provider/service real
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (!mounted) return;

      // Obtener datos del vehículo desde conductorUser o backend
      final vehiculo = widget.conductorUser?['vehiculo'] as Map<String, dynamic>?;
      
      setState(() {
        _vehicleData = vehiculo ?? {
          'marca': widget.conductorUser?['vehiculo_marca'] ?? 'Toyota',
          'modelo': widget.conductorUser?['vehiculo_modelo'] ?? 'Corolla',
          'anio': widget.conductorUser?['vehiculo_anio'] ?? 2022,
          'placa': widget.conductorUser?['placa'] ?? 'ABC-123',
          'color': widget.conductorUser?['vehiculo_color'] ?? 'Blanco',
          'tipo_vehiculo': widget.conductorUser?['tipo_vehiculo'] ?? 'auto',
          'capacidad_pasajeros': widget.conductorUser?['capacidad_pasajeros'] ?? 4,
          'combustible': 'Gasolina',
          'aire_acondicionado': true,
          'verificado': widget.conductorUser?['vehiculo_verificado'] ?? false,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Error al cargar la información del vehículo';
        _isLoading = false;
      });
    }
  }

  void _handleEditVehicle() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Función de edición próximamente'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleRegisterVehicle() {
    // Navegar a registro de vehículo
    Navigator.pushNamed(context, '/conductor/vehicle-registration');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: widget.conductorUser != null
          ? ConductorDrawer(conductorUser: widget.conductorUser!)
          : null,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: _buildContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      leading: widget.conductorUser != null
          ? IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            )
          : IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _headerController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Mi Vehículo',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Información y estado de tu vehículo',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const VehicleShimmer();
    }

    if (_hasError) {
      return VehicleEmptyState(
        errorMessage: _errorMessage,
        onRetry: _loadVehicleData,
      );
    }

    if (_vehicleData == null) {
      return VehicleEmptyState(
        onRegister: _handleRegisterVehicle,
      );
    }

    final isVerified = _vehicleData?['verificado'] == true;

    return RefreshIndicator(
      onRefresh: _loadVehicleData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VehicleInfoCard(
              vehicleData: _vehicleData,
              onEdit: _handleEditVehicle,
            ),
            const SizedBox(height: 20),
            VehicleStatusCard(
              isVerified: isVerified,
              statusMessage: isVerified
                  ? 'Tu vehículo está verificado y listo para operar'
                  : 'Completa la verificación para comenzar',
              onVerify: isVerified ? null : _handleRegisterVehicle,
            ),
            const SizedBox(height: 24),
            VehicleDetailsSection(vehicleData: _vehicleData),
            const SizedBox(height: 24),
            _buildDocumentsSection(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documentos del Vehículo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDocumentCard(
                icon: Icons.description_rounded,
                title: 'Tarjeta de Circulación',
                isValid: true,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDocumentCard(
                icon: Icons.security_rounded,
                title: 'Seguro',
                isValid: true,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDocumentCard(
                icon: Icons.verified_rounded,
                title: 'Verificación Vehicular',
                isValid: false,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDocumentCard(
                icon: Icons.local_taxi_rounded,
                title: 'Permiso de Taxi',
                isValid: true,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentCard({
    required IconData icon,
    required String title,
    required bool isValid,
    required bool isDark,
  }) {
    final color = isValid ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const Spacer(),
              Icon(
                isValid ? Icons.check_circle_rounded : Icons.warning_rounded,
                size: 18,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isValid ? 'Vigente' : 'Por vencer',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

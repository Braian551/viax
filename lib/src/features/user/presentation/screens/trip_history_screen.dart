import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../providers/user_trips_provider.dart';
import '../widgets/trip_history/trip_history_widgets.dart';

/// Pantalla de historial de viajes y pagos del usuario
/// Con arquitectura limpia, widgets reutilizables y animaciones fluidas
/// Soporta modo oscuro y claro
class TripHistoryScreen extends StatelessWidget {
  final int userId;

  const TripHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserTripsProvider(),
      child: _TripHistoryContent(userId: userId),
    );
  }
}

class _TripHistoryContent extends StatefulWidget {
  final int userId;

  const _TripHistoryContent({required this.userId});

  @override
  State<_TripHistoryContent> createState() => _TripHistoryContentState();
}

class _TripHistoryContentState extends State<_TripHistoryContent>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;
  late ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerSlideAnimation = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _headerFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _scrollController = ScrollController()..addListener(_onScroll);

    _headerAnimationController.forward();

    // Cargar datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _onScroll() {
    final isScrolled = _scrollController.offset > 100;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }
  }

  Future<void> _loadData() async {
    final provider = context.read<UserTripsProvider>();
    await provider.refresh(userId: widget.userId);
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Consumer<UserTripsProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => provider.refresh(userId: widget.userId),
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // AppBar animado
                  _buildAnimatedAppBar(isDark, textColor, backgroundColor, surfaceColor),

                  // Header con resumen de pagos
                  if (provider.paymentSummary != null)
                    SliverToBoxAdapter(
                      child: TripHistoryHeader(
                        totalPagado: provider.paymentSummary!.totalPagado,
                        totalViajes: provider.paymentSummary!.totalViajes,
                        promedioPorViaje:
                            provider.paymentSummary!.promedioPorViaje,
                      ),
                    ),

                  // Grid de estadísticas
                  SliverToBoxAdapter(
                    child: TripHistorySummaryGrid(
                      totalViajes: provider.totalTrips,
                      completados: provider.completedTrips,
                      cancelados: provider.cancelledTrips,
                      isDark: isDark,
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),

                  // Filtros
                  SliverToBoxAdapter(
                    child: TripHistoryFilters(
                      selectedFilter: provider.selectedFilter,
                      onFilterChanged: (filter) {
                        provider.setFilter(filter, userId: widget.userId);
                      },
                      isDark: isDark,
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 8),
                  ),

                  // Lista de viajes
                  _buildTripsList(provider, isDark),

                  // Espacio inferior
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedAppBar(bool isDark, Color textColor, Color backgroundColor, Color surfaceColor) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: _isScrolled ? surfaceColor.withValues(alpha: 0.9) : backgroundColor,
      flexibleSpace: _isScrolled
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            )
          : null,
      leading: null,
      automaticallyImplyLeading: false, 
      centerTitle: false,
      titleSpacing: 20,
      title: AnimatedBuilder(
        animation: _headerAnimationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_headerSlideAnimation.value),
            child: Opacity(
              opacity: _headerFadeAnimation.value,
              child: child,
            ),
          );
        },
        child: Text(
          'Mis Viajes',
          style: TextStyle(
            color: textColor,
            fontSize: 28, // Bigger, bolder title
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _headerAnimationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(-_headerSlideAnimation.value, 0),
              child: Opacity(
                opacity: _headerFadeAnimation.value,
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.calendar_month_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 22,
              ),
              tooltip: 'Filtrar por fecha',
              onPressed: () => _showDateFilter(context, isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripsList(UserTripsProvider provider, bool isDark) {
    // Estado de carga
    if (provider.loadState == LoadState.loading && provider.trips.isEmpty) {
      return SliverToBoxAdapter(
        child: TripHistoryShimmer(itemCount: 4, isDark: isDark),
      );
    }

    // Estado vacío
    if (provider.trips.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: TripHistoryEmptyState(
          filterText: provider.selectedFilter != 'all'
              ? _getFilterLabel(provider.selectedFilter)
              : null,
          onRefresh: () => provider.refresh(userId: widget.userId),
          isDark: isDark,
        ),
      );
    }

    // Lista de viajes
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Cargar más al llegar al final
          if (index == provider.trips.length - 1 && provider.hasMore) {
            provider.loadMore(userId: widget.userId);
          }

          final trip = provider.trips[index];
          return TripHistoryCard(
            trip: trip,
            index: index,
            isDark: isDark,
            onTap: () => TripDetailBottomSheet.show(context, trip, isDark: isDark),
          );
        },
        childCount: provider.trips.length,
      ),
    );
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'completada':
        return 'completados';
      case 'cancelada':
        return 'cancelados';
      case 'en_curso':
        return 'en curso';
      default:
        return '';
    }
  }

  void _showDateFilter(BuildContext context, bool isDark) {
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white; // Darker surface
    final textColor = isDark ? Colors.white : Colors.black87;
    
    // Capture the provider from the current context before showing the modal
    final provider = context.read<UserTripsProvider>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow it to take needed space and feel better
      builder: (modalContext) => ChangeNotifierProvider.value(
        value: provider,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              Text(
                'Filtrar por fecha',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildDateOption(
                context,
                'Última semana',
                Icons.calendar_view_week_rounded,
                () {
                  final now = DateTime.now();
                  final start = now.subtract(const Duration(days: 7));
                  context.read<UserTripsProvider>().setDateFilter(start, now, userId: widget.userId);
                },
                isDark,
              ),
              _buildDateOption(
                context,
                'Último mes',
                Icons.calendar_view_month_rounded,
                () {
                  final now = DateTime.now();
                  final start = now.subtract(const Duration(days: 30));
                  context.read<UserTripsProvider>().setDateFilter(start, now, userId: widget.userId);
                },
                isDark,
              ),
              _buildDateOption(
                context,
                'Últimos 3 meses',
                Icons.history_rounded,
                () {
                  final now = DateTime.now();
                  final start = now.subtract(const Duration(days: 90));
                  context.read<UserTripsProvider>().setDateFilter(start, now, userId: widget.userId);
                },
                isDark,
              ),
              _buildDateOption(
                context,
                'Personalizado',
                Icons.date_range_rounded,
                () async {
                  final result = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.black, // Text on primary
                            surface: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            onSurface: isDark ? Colors.white : Colors.black,
                          ), dialogTheme: DialogThemeData(backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white),
                        ),
                        child: child!,
                      );
                    },
                  );
                  
                  if (result != null && context.mounted) {
                    context.read<UserTripsProvider>().setDateFilter(
                      result.start, 
                      result.end, 
                      userId: widget.userId
                    );
                  }
                },
                isDark,
              ),
              
            // Opción para limpiar filtro
            if (context.read<UserTripsProvider>().startDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  onPressed: () {
                     context.read<UserTripsProvider>().setDateFilter(null, null, userId: widget.userId);
                     Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Limpiar filtro'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5252),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateOption(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87;
    final baseColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final iconColor = isDark ? const Color(0xFF64B5F6) : AppColors.primary; // Lighter blue for dark mode
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: textColor.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

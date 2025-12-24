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
      elevation: _isScrolled ? 4 : 0,
      backgroundColor: _isScrolled ? surfaceColor : backgroundColor,
      leading: AnimatedBuilder(
        animation: _headerAnimationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_headerSlideAnimation.value, 0),
            child: Opacity(
              opacity: _headerFadeAnimation.value,
              child: child,
            ),
          );
        },
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: textColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          'Mis viajes',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            onPressed: () => _showDateFilter(context, isDark),
          ),
        ),
        const SizedBox(width: 8),
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
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final dividerColor = isDark ? AppColors.darkDivider : Colors.grey.shade300;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Filtrar por fecha',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            _buildDateOption(
              context,
              'Última semana',
              Icons.calendar_today_rounded,
              () {},
              isDark,
            ),
            _buildDateOption(
              context,
              'Último mes',
              Icons.date_range_rounded,
              () {},
              isDark,
            ),
            _buildDateOption(
              context,
              'Últimos 3 meses',
              Icons.calendar_month_rounded,
              () {},
              isDark,
            ),
            _buildDateOption(
              context,
              'Personalizado',
              Icons.edit_calendar_rounded,
              () {},
              isDark,
            ),
            const SizedBox(height: 16),
          ],
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
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final borderColor = isDark 
        ? AppColors.primary.withOpacity(0.2) 
        : AppColors.primary.withOpacity(0.1);
    
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: textColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

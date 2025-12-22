import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../providers/conductor_trips_provider.dart';
import '../../services/conductor_trips_service.dart';
import '../widgets/conductor_drawer.dart';
import '../widgets/trip_history/trip_history_widgets.dart';

/// Pantalla de Historial de Viajes del Conductor
/// 
/// Muestra el historial completo de viajes realizados con filtros,
/// animaciones fluidas y diseño consistente con el tema de la app.
class ConductorTripsScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;

  const ConductorTripsScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
  });

  @override
  State<ConductorTripsScreen> createState() => _ConductorTripsScreenState();
}

class _ConductorTripsScreenState extends State<ConductorTripsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isInitialized = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      // Defer loading to after build completes to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTrips();
      });
    }
  }

  Future<void> _loadTrips() async {
    if (!mounted) return;
    final provider = Provider.of<ConductorTripsProvider>(context, listen: false);
    try {
      await provider.loadTrips(widget.conductorId);
    } catch (e) {
      debugPrint('Error loading trips: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Configurar el estilo de la barra de estado
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      drawer: widget.conductorUser != null
          ? ConductorDrawer(conductorUser: widget.conductorUser!)
          : null,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              _buildAppBar(isDark),
              _buildFilters(),
              Expanded(child: _buildContent(isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCard.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Botón menú/atrás
                _buildAppBarButton(
                  icon: widget.conductorUser != null
                      ? Icons.menu_rounded
                      : Icons.arrow_back_rounded,
                  onTap: () {
                    if (widget.conductorUser != null) {
                      _scaffoldKey.currentState?.openDrawer();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),

                // Título o campo de búsqueda
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isSearching
                        ? _buildSearchField(isDark)
                        : _buildTitle(isDark),
                  ),
                ),

                // Botón de búsqueda
                _buildAppBarButton(
                  icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
                  onTap: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                      }
                    });
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark) {
    return Text(
      'Historial de Viajes',
      key: const ValueKey('title'),
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      key: const ValueKey('search'),
      controller: _searchController,
      autofocus: true,
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar viaje...',
        hintStyle: TextStyle(
          color: isDark ? Colors.white54 : AppColors.lightTextHint,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onChanged: (value) {
        // TODO: Implementar búsqueda
      },
    );
  }

  Widget _buildFilters() {
    return Consumer<ConductorTripsProvider>(
      builder: (context, provider, _) {
        return TripFilterChips(
          selectedFilter: provider.filterStatus,
          onFilterChanged: (filter) {
            provider.setFilter(filter);
            HapticFeedback.selectionClick();
          },
        );
      },
    );
  }

  Widget _buildContent(bool isDark) {
    return Consumer<ConductorTripsProvider>(
      builder: (context, provider, _) {
        // Estado de carga
        if (provider.isLoading && provider.trips.isEmpty) {
          return const TripHistoryShimmer();
        }

        // Estado de error
        if (provider.errorMessage != null && provider.trips.isEmpty) {
          return TripHistoryEmptyState(
            isError: true,
            errorMessage: provider.errorMessage,
            onRetry: _loadTrips,
          );
        }

        // Estado vacío
        if (provider.trips.isEmpty) {
          return const TripHistoryEmptyState();
        }

        // Lista de viajes
        return RefreshIndicator(
          onRefresh: _loadTrips,
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          child: _buildTripsList(provider.trips, isDark),
        );
      },
    );
  }

  Widget _buildTripsList(List<TripModel> trips, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripHistoryCard(
          trip: trip,
          index: index,
          onTap: () => TripDetailBottomSheet.show(context, trip),
        );
      },
    );
  }
}

import 'package:flutter/foundation.dart';
import '../services/user_trips_service.dart';

/// Estado de carga
enum LoadState { initial, loading, loaded, error }

/// Provider para manejar el historial de viajes del usuario
class UserTripsProvider extends ChangeNotifier {
  List<UserTripModel> _trips = [];
  UserPaymentSummary? _paymentSummary;
  LoadState _loadState = LoadState.initial;
  String _errorMessage = '';
  String _selectedFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  bool _hasMore = true;

  // Getters
  List<UserTripModel> get trips => _trips;
  UserPaymentSummary? get paymentSummary => _paymentSummary;
  LoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;
  String get selectedFilter => _selectedFilter;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool get isLoading => _loadState == LoadState.loading;
  bool get hasMore => _hasMore;

  // Estadísticas rápidas
  int get totalTrips => _trips.length;
  int get completedTrips => _trips.where((t) => t.isCompletado).length;
  int get cancelledTrips => _trips.where((t) => t.isCancelado).length;

  /// Cargar viajes del usuario
  Future<void> loadTrips({
    required int userId,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (_loadState == LoadState.loading && !refresh) return;
    
    _loadState = LoadState.loading;
    notifyListeners();

    final result = await UserTripsService.getHistorial(
      userId: userId,
      page: _currentPage,
      estado: _selectedFilter == 'all' ? null : _selectedFilter,
      fechaInicio: _startDate,
      fechaFin: _endDate,
    );

    if (result['success'] == true) {
      final viajes = result['viajes'] as List<UserTripModel>;
      
      if (refresh || _currentPage == 1) {
        _trips = viajes;
      } else {
        _trips.addAll(viajes);
      }

      // Verificar si hay más páginas
      final pagination = result['pagination'];
      if (pagination != null) {
        _hasMore = _currentPage < (pagination['total_pages'] ?? 1);
      } else {
        _hasMore = viajes.isNotEmpty && viajes.length >= 20;
      }

      _loadState = LoadState.loaded;
      _errorMessage = '';
    } else {
      _loadState = LoadState.error;
      _errorMessage = result['error'] ?? 'Error al cargar viajes';
    }

    notifyListeners();
  }

  /// Cargar más viajes (paginación)
  Future<void> loadMore({required int userId}) async {
    if (!_hasMore || _loadState == LoadState.loading) return;
    _currentPage++;
    await loadTrips(userId: userId);
  }

  /// Cargar resumen de pagos
  Future<void> loadPaymentSummary({required int userId}) async {
    final summary = await UserTripsService.getPaymentSummary(
      userId: userId,
      fechaInicio: _startDate?.toIso8601String().split('T')[0],
      fechaFin: _endDate?.toIso8601String().split('T')[0],
    );
    if (summary != null) {
      _paymentSummary = summary;
      notifyListeners();
    }
  }

  /// Cambiar filtro de estado
  void setFilter(String filter, {required int userId}) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      _trips = [];
      loadTrips(userId: userId, refresh: true);
    }
  }

  /// Establecer filtro de fechas
  void setDateFilter(DateTime? start, DateTime? end, {required int userId}) {
    _startDate = start;
    _endDate = end;
    refresh(userId: userId);
  }

  /// Refrescar todo
  Future<void> refresh({required int userId}) async {
    await Future.wait([
      loadTrips(userId: userId, refresh: true),
      loadPaymentSummary(userId: userId),
    ]);
  }

  /// Limpiar estado
  void clear() {
    _trips = [];
    _paymentSummary = null;
    _loadState = LoadState.initial;
    _selectedFilter = 'all';
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }
}

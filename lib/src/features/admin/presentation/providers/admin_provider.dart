import 'package:flutter/foundation.dart';
import '../../domain/entities/admin.dart';
import '../../domain/usecases/get_system_stats.dart';
import '../../domain/usecases/approve_driver.dart';
import '../../domain/usecases/reject_driver.dart';

/// Provider para gestionar el estado de administraciÃ³n
class AdminProvider with ChangeNotifier {
  final GetSystemStats getSystemStatsUseCase;
  final ApproveDriver approveDriverUseCase;
  final RejectDriver rejectDriverUseCase;

  AdminProvider({
    required this.getSystemStatsUseCase,
    required this.approveDriverUseCase,
    required this.rejectDriverUseCase,
  });

  SystemStats? _stats;
  final List<Map<String, dynamic>> _pendingDrivers = [];
  bool _isLoading = false;
  String? _errorMessage;

  SystemStats? get stats => _stats;
  List<Map<String, dynamic>> get pendingDrivers => _pendingDrivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Cargar estadÃ­sticas
  Future<void> loadStats() async {
    _setLoading(true);

    final result = await getSystemStatsUseCase();

    result.when(
      success: (stats) {
        _stats = stats;
        _setLoading(false);
      },
      error: (failure) {
        _setError(failure.message);
      },
    );
  }

  /// Aprobar conductor
  Future<bool> approveDriver(int conductorId) async {
    _setLoading(true);

    final result = await approveDriverUseCase(conductorId);

    return result.when(
      success: (_) {
        _pendingDrivers.removeWhere((d) => d['id'] == conductorId);
        _setLoading(false);
        return true;
      },
      error: (failure) {
        _setError(failure.message);
        return false;
      },
    );
  }

  /// Rechazar conductor
  Future<bool> rejectDriver(int conductorId, String motivo) async {
    _setLoading(true);

    final result = await rejectDriverUseCase(conductorId, motivo);

    return result.when(
      success: (_) {
        _pendingDrivers.removeWhere((d) => d['id'] == conductorId);
        _setLoading(false);
        return true;
      },
      error: (failure) {
        _setError(failure.message);
        return false;
      },
    );
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _isLoading = false;
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

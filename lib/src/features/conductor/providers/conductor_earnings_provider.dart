import 'package:flutter/material.dart';
import '../services/conductor_earnings_service.dart';

enum EarningsPeriod { today, week, month }

class ConductorEarningsProvider with ChangeNotifier {
  EarningsModel? _earnings;
  bool _isLoading = false;
  String? _errorMessage;
  EarningsPeriod _selectedPeriod = EarningsPeriod.today;
  // These fields are intentionally kept to remember the custom range and may be read by UI later.
  // ignore: unused_field
  DateTime? _customStart;
  // ignore: unused_field
  DateTime? _customEnd;

  EarningsModel? get earnings => _earnings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  EarningsPeriod get selectedPeriod => _selectedPeriod;

  /// Cargar ganancias segÃºn el perÃ­odo seleccionado
  Future<void> loadEarnings(int conductorId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Map<String, dynamic> response;

      switch (_selectedPeriod) {
        case EarningsPeriod.today:
          response = await ConductorEarningsService.getTodayEarnings(
            conductorId: conductorId,
          );
          break;
        case EarningsPeriod.week:
          response = await ConductorEarningsService.getWeekEarnings(
            conductorId: conductorId,
          );
          break;
        case EarningsPeriod.month:
          response = await ConductorEarningsService.getMonthEarnings(
            conductorId: conductorId,
          );
          break;
      }

      if (response['success'] == true) {
        _earnings = response['ganancias'];
        _errorMessage = null;
      } else {
        _errorMessage = response['message'] ?? 'Error al cargar ganancias';
        _earnings = EarningsModel(
          total: 0,
          totalViajes: 0,
          promedioPorViaje: 0,
          desgloseDiario: [],
        );
      }
    } catch (e) {
      _errorMessage = 'Error de conexiÃ³n: $e';
      _earnings = EarningsModel(
        total: 0,
        totalViajes: 0,
        promedioPorViaje: 0,
        desgloseDiario: [],
      );
      print('Error en loadEarnings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar ganancias con fechas personalizadas
  Future<void> loadCustomEarnings(
    int conductorId,
    DateTime start,
    DateTime end,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _customStart = start;
    _customEnd = end;
    notifyListeners();

    try {
      final response = await ConductorEarningsService.getEarnings(
        conductorId: conductorId,
        fechaInicio: start,
        fechaFin: end,
      );

      if (response['success'] == true) {
        _earnings = response['ganancias'];
        _errorMessage = null;
      } else {
        _errorMessage = response['message'] ?? 'Error al cargar ganancias';
        _earnings = EarningsModel(
          total: 0,
          totalViajes: 0,
          promedioPorViaje: 0,
          desgloseDiario: [],
        );
      }
    } catch (e) {
      _errorMessage = 'Error de conexiÃ³n: $e';
      _earnings = EarningsModel(
        total: 0,
        totalViajes: 0,
        promedioPorViaje: 0,
        desgloseDiario: [],
      );
      print('Error en loadCustomEarnings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cambiar perÃ­odo seleccionado
  void setPeriod(EarningsPeriod period, int conductorId) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      _customStart = null;
      _customEnd = null;
      notifyListeners();
      loadEarnings(conductorId);
    }
  }

  /// Obtener ganancias de hoy
  double get todayEarnings {
    if (_earnings == null) return 0;
    if (_selectedPeriod != EarningsPeriod.today) return 0;
    return _earnings!.total;
  }

  /// Obtener ganancias de la semana
  double get weekEarnings {
    if (_earnings == null) return 0;
    if (_selectedPeriod != EarningsPeriod.week) return 0;
    return _earnings!.total;
  }

  /// Obtener ganancias del mes
  double get monthEarnings {
    if (_earnings == null) return 0;
    if (_selectedPeriod != EarningsPeriod.month) return 0;
    return _earnings!.total;
  }

  /// Limpiar datos
  void clear() {
    _earnings = null;
    _isLoading = false;
    _errorMessage = null;
    _selectedPeriod = EarningsPeriod.today;
    _customStart = null;
    _customEnd = null;
    notifyListeners();
  }
}

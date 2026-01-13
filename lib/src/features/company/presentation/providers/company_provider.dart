/// Company Provider
/// Manages state for company-related screens

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/datasources/company_remote_datasource.dart';
import '../../data/repositories/company_repository_impl.dart';
import '../../domain/usecases/get_company_drivers.dart';
import '../../domain/usecases/get_company_pricing.dart';
import '../../domain/usecases/update_company_pricing.dart';
import '../../domain/usecases/get_company_details.dart';
import '../../domain/models/company_reports_model.dart';

class CompanyProvider extends ChangeNotifier {
  final dynamic empresaId;

  late final CompanyRepositoryImpl _repository;
  late final CompanyRemoteDataSourceImpl _dataSource;
  late final GetCompanyDrivers _getDrivers;
  late final GetCompanyPricing _getPricing;
  late final UpdateCompanyPricing _updatePricing;
  late final GetCompanyDetails _getCompanyDetails;

  // State
  bool _isLoadingDrivers = false;
  bool _isLoadingPricing = false;
  bool _isSaving = false;
  bool _isLoadingCompany = false;
  bool _isLoadingStats = false;
  bool _isLoadingReports = false;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _pricing = [];
  Map<String, dynamic>? _company;
  Map<String, dynamic>? _dashboardStats;
  CompanyReportsData? _reportsData;
  String _selectedReportPeriod = '7d';
  String? _errorMessage;
  String? _reportsError;

  // Getters
  bool get isLoadingDrivers => _isLoadingDrivers;
  bool get isLoadingPricing => _isLoadingPricing;
  bool get isLoadingCompany => _isLoadingCompany;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingReports => _isLoadingReports;
  bool get isSaving => _isSaving;
  List<Map<String, dynamic>> get drivers => _drivers;
  List<Map<String, dynamic>> get pricing => _pricing;
  Map<String, dynamic>? get company => _company;
  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  CompanyReportsData? get reportsData => _reportsData;
  String get selectedReportPeriod => _selectedReportPeriod;
  String? get errorMessage => _errorMessage;
  String? get reportsError => _reportsError;
  int get driverCount => _drivers.length;

  // Dashboard stats getters
  int get viajesHoy => _dashboardStats?['viajes']?['hoy'] ?? 0;
  int get totalConductores => _dashboardStats?['conductores']?['total'] ?? 0;
  String get gananciasDisplay =>
      _dashboardStats?['ganancias']?['display'] ?? '\$0';
  int get solicitudesPendientes =>
      _dashboardStats?['solicitudes_pendientes'] ?? 0;
  double get calificacionPromedio =>
      (_dashboardStats?['calificacion']?['promedio'] ?? 0.0).toDouble();

  CompanyProvider({required this.empresaId}) {
    _dataSource = CompanyRemoteDataSourceImpl(client: http.Client());
    _repository = CompanyRepositoryImpl(remoteDataSource: _dataSource);
    _getDrivers = GetCompanyDrivers(_repository);
    _getPricing = GetCompanyPricing(_repository);
    _updatePricing = UpdateCompanyPricing(_repository);
    _getCompanyDetails = GetCompanyDetails(_repository);
  }

  Future<void> loadCompanyDetails() async {
    print('CompanyProvider: Loading details for empresaId: $empresaId');
    if (empresaId == null) {
      print('CompanyProvider: empresaId is null, skipping load');
      return;
    }

    _isLoadingCompany = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _getCompanyDetails(empresaId);
    result.fold(
      (failure) {
        print('CompanyProvider: Load failed: ${failure.message}');
        _errorMessage = failure.message;
      },
      (data) {
        print('CompanyProvider: Load success! Company: ${data['nombre']}');
        _company = data;
      },
    );

    _isLoadingCompany = false;
    notifyListeners();

    // Cargar estadísticas del dashboard después de los detalles
    await loadDashboardStats();
  }

  Future<bool> updateCompanyProfile(Map<String, dynamic> data, {File? logoFile}) async {
    if (empresaId == null) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedData = await _dataSource.updateCompanyDetails(empresaId, data, logoFile: logoFile);
      _company = updatedData;
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('CompanyProvider: Error updating company profile: $e');
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadDashboardStats({String periodo = 'hoy'}) async {
    if (empresaId == null) return;

    _isLoadingStats = true;
    notifyListeners();

    try {
      final stats = await _dataSource.getDashboardStats(
        empresaId: empresaId,
        periodo: periodo,
      );
      _dashboardStats = stats;
      print('CompanyProvider: Dashboard stats loaded: $stats');
    } catch (e) {
      print('CompanyProvider: Error loading dashboard stats: $e');
      // No actualizamos el error para no bloquear la UI
    }

    _isLoadingStats = false;
    notifyListeners();
  }

  Future<void> loadDrivers() async {
    _isLoadingDrivers = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _getDrivers(empresaId);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _drivers = [];
      },
      (data) {
        _drivers = data;
      },
    );

    _isLoadingDrivers = false;
    notifyListeners();
  }

  Future<void> loadPricing() async {
    _isLoadingPricing = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _getPricing(empresaId);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _pricing = [];
      },
      (data) {
        _pricing = data;
      },
    );

    _isLoadingPricing = false;
    notifyListeners();
  }

  Future<bool> savePricing(List<Map<String, dynamic>> precios) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _updatePricing(empresaId, precios);
    bool success = false;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (data) {
        success = data;
      },
    );

    _isSaving = false;
    notifyListeners();

    if (success) {
      await loadPricing(); // Refresh after save
    }

    return success;
  }

  /// Cargar reportes avanzados de la empresa
  Future<void> loadReports({String? periodo}) async {
    if (empresaId == null) return;

    if (periodo != null) {
      _selectedReportPeriod = periodo;
    }

    _isLoadingReports = true;
    _reportsError = null;
    notifyListeners();

    try {
      final data = await _dataSource.getReports(
        empresaId: empresaId,
        periodo: _selectedReportPeriod,
      );
      _reportsData = CompanyReportsData.fromJson(data);
      print('CompanyProvider: Reports loaded successfully');
    } catch (e) {
      print('CompanyProvider: Error loading reports: $e');
      _reportsError = e.toString();
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  /// Cambiar periodo de reportes
  void setReportPeriod(String periodo) {
    if (_selectedReportPeriod != periodo) {
      loadReports(periodo: periodo);
    }
  }

  // Settings State
  bool _isLoadingSettings = false;
  Map<String, dynamic> _settings = {};

  bool get isLoadingSettings => _isLoadingSettings;
  Map<String, dynamic> get settings => _settings;

  Future<void> loadSettings() async {
    if (empresaId == null) return;

    _isLoadingSettings = true;
    notifyListeners();

    try {
      final data = await _dataSource.getCompanySettings(empresaId);
      _settings = data;
    } catch (e) {
      print('CompanyProvider: Error loading settings: $e');
      // Set defaults on error
      _settings = {
        'notificaciones_email': true,
        'notificaciones_push': true,
      };
    }

    _isLoadingSettings = false;
    notifyListeners();
  }

  Future<bool> updateSettings(Map<String, dynamic> newSettings) async {
    if (empresaId == null) return false;

    // Optimistic update
    final oldSettings = Map<String, dynamic>.from(_settings);
    _settings = {..._settings, ...newSettings};
    notifyListeners();

    try {
      final updatedData = await _dataSource.updateCompanySettings(empresaId, newSettings);
      _settings = updatedData;
      notifyListeners();
      return true;
    } catch (e) {
      print('CompanyProvider: Error updating settings: $e');
      // Revert on error
      _settings = oldSettings;
      _errorMessage = 'Error al guardar la configuración';
      notifyListeners();
      return false;
    }
  }

  // Security State
  bool _isCheckingPassword = false;
  bool _hasPassword = true;
  String _authProvider = 'email';

  bool get isCheckingPassword => _isCheckingPassword;
  bool get hasPassword => _hasPassword;
  String get authProvider => _authProvider;

  /// Check if current user has a password set
  Future<void> checkPasswordStatus(dynamic userId) async {
    if (userId == null) return;

    _isCheckingPassword = true;
    notifyListeners();

    try {
      final status = await _dataSource.checkPasswordStatus(userId);
      _hasPassword = status['has_password'] ?? true;
      _authProvider = status['auth_provider'] ?? 'email';
    } catch (e) {
      print('CompanyProvider: Error checking password status: $e');
      // Default to assuming password exists to show change form
      _hasPassword = true;
      _authProvider = 'email';
    }

    _isCheckingPassword = false;
    notifyListeners();
  }

  /// Change or set password
  Future<bool> changePassword({
    required dynamic userId,
    String? currentPassword,
    required String newPassword,
  }) async {
    if (userId == null) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _dataSource.changePassword(
        userId: userId,
        currentPassword: currentPassword,
        newPassword: newPassword,
        isSettingNew: !_hasPassword,
      );
      
      if (success) {
        _hasPassword = true; // Now user has a password
      }
      
      _isSaving = false;
      notifyListeners();
      return success;
    } catch (e) {
      print('CompanyProvider: Error changing password: $e');
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}

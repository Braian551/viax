/// Company Provider
/// Manages state for company-related screens

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/datasources/company_remote_datasource.dart';
import '../../data/repositories/company_repository_impl.dart';
import '../../domain/usecases/get_company_drivers.dart';
import '../../domain/usecases/get_company_pricing.dart';
import '../../domain/usecases/get_company_pricing.dart';
import '../../domain/usecases/update_company_pricing.dart';
import '../../domain/usecases/get_company_details.dart';

class CompanyProvider extends ChangeNotifier {
  final dynamic empresaId;
  
  late final CompanyRepositoryImpl _repository;
  late final GetCompanyDrivers _getDrivers;
  late final GetCompanyPricing _getPricing;
  late final UpdateCompanyPricing _updatePricing;
  late final GetCompanyDetails _getCompanyDetails;

  // State
  bool _isLoadingDrivers = false;
  bool _isLoadingPricing = false;
  bool _isSaving = false;
  bool _isLoadingCompany = false;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _pricing = [];
  Map<String, dynamic>? _company;
  String? _errorMessage;

  // Getters
  bool get isLoadingDrivers => _isLoadingDrivers;
  bool get isLoadingPricing => _isLoadingPricing;
  bool get isLoadingCompany => _isLoadingCompany;
  bool get isSaving => _isSaving;
  List<Map<String, dynamic>> get drivers => _drivers;
  List<Map<String, dynamic>> get pricing => _pricing;
  Map<String, dynamic>? get company => _company;
  String? get errorMessage => _errorMessage;
  int get driverCount => _drivers.length;

  CompanyProvider({required this.empresaId}) {
    final dataSource = CompanyRemoteDataSourceImpl(client: http.Client());
    _repository = CompanyRepositoryImpl(remoteDataSource: dataSource);
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
}

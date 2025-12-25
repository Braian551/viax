import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/datasources/empresa_remote_datasource.dart';
import '../../data/models/empresa_transporte_model.dart';
import '../../data/repositories/empresa_repository_impl.dart';
import '../../domain/entities/empresa_transporte.dart';
import '../../domain/repositories/empresa_repository.dart';

/// Estados posibles del provider de empresas
enum EmpresaProviderState {
  initial,
  loading,
  loaded,
  error,
  creating,
  updating,
  deleting,
}

/// Provider para gestionar el estado de las empresas de transporte
class EmpresaProvider extends ChangeNotifier {
  final EmpresaRepository _repository;
  
  // Estado
  EmpresaProviderState _state = EmpresaProviderState.initial;
  String? _errorMessage;
  
  // Datos
  List<EmpresaTransporte> _empresas = [];
  EmpresaTransporte? _selectedEmpresa;
  EmpresaStats? _stats;
  
  // Filtros
  String? _estadoFilter;
  String? _municipioFilter;
  String? _searchQuery;
  
  // Paginación
  int _currentPage = 1;
  int _totalPages = 1;
  static const int _pageSize = 20;

  EmpresaProvider({EmpresaRepository? repository})
      : _repository = repository ?? _createDefaultRepository();

  static EmpresaRepository _createDefaultRepository() {
    return EmpresaRepositoryImpl(
      remoteDataSource: EmpresaRemoteDataSourceImpl(client: http.Client()),
    );
  }

  // Getters
  EmpresaProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  List<EmpresaTransporte> get empresas => _empresas;
  EmpresaTransporte? get selectedEmpresa => _selectedEmpresa;
  EmpresaStats? get stats => _stats;
  bool get isLoading => _state == EmpresaProviderState.loading;
  bool get hasError => _state == EmpresaProviderState.error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  
  // Getters filtrados
  List<EmpresaTransporte> get empresasActivas => 
      _empresas.where((e) => e.estado == EmpresaEstado.activo).toList();
  
  List<EmpresaTransporte> get empresasPendientes => 
      _empresas.where((e) => e.estado == EmpresaEstado.pendiente).toList();

  /// Carga la lista de empresas
  Future<void> loadEmpresas({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
    }
    
    _state = EmpresaProviderState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final empresas = await _repository.getEmpresas(
        estado: _estadoFilter,
        municipio: _municipioFilter,
        search: _searchQuery,
        page: _currentPage,
        limit: _pageSize,
      );

      _empresas = empresas;
      _state = EmpresaProviderState.loaded;
    } catch (e) {
      _state = EmpresaProviderState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Carga más empresas (paginación)
  Future<void> loadMoreEmpresas() async {
    if (_currentPage >= _totalPages || _state == EmpresaProviderState.loading) {
      return;
    }

    _currentPage++;
    await loadEmpresas();
  }

  /// Carga una empresa específica por ID
  Future<void> loadEmpresaById(int id) async {
    _state = EmpresaProviderState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedEmpresa = await _repository.getEmpresaById(id);
      _state = EmpresaProviderState.loaded;
    } catch (e) {
      _state = EmpresaProviderState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Crea una nueva empresa
  Future<int?> createEmpresa(EmpresaFormData formData, int adminId) async {
    _state = EmpresaProviderState.creating;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = formData.toJson();
      if (formData.logoFile != null) {
        data['logo_file'] = formData.logoFile;
      }

      final empresaId = await _repository.createEmpresa(
        data,
        adminId,
      );
      
      _state = EmpresaProviderState.loaded;
      
      // Recargar lista
      await loadEmpresas(refresh: true);
      
      return empresaId;
    } catch (e) {
      _state = EmpresaProviderState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Actualiza una empresa existente
  Future<bool> updateEmpresa(int id, EmpresaFormData formData, int adminId) async {
    _state = EmpresaProviderState.updating;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = formData.toJson();
      if (formData.logoFile != null) {
        data['logo_file'] = formData.logoFile;
      }

      await _repository.updateEmpresa(
        id,
        data,
        adminId,
      );
      
      _state = EmpresaProviderState.loaded;
      
      // Recargar lista
      await loadEmpresas(refresh: true);
      
      return true;
    } catch (e) {
      _state = EmpresaProviderState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Elimina una empresa
  Future<bool> deleteEmpresa(int id, int adminId) async {
    _state = EmpresaProviderState.deleting;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteEmpresa(id, adminId);
      
      _state = EmpresaProviderState.loaded;
      
      // Remover de la lista local
      _empresas.removeWhere((e) => e.id == id);
      notifyListeners();
      
      return true;
    } catch (e) {
      _state = EmpresaProviderState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Cambia el estado de una empresa
  Future<bool> toggleEmpresaStatus(int id, String nuevoEstado, int adminId) async {
    try {
      await _repository.toggleEmpresaStatus(id, nuevoEstado, adminId);
      
      // Actualizar localmente
      final index = _empresas.indexWhere((e) => e.id == id);
      if (index != -1) {
        final empresa = _empresas[index];
        _empresas[index] = empresa.copyWith(
          estado: EmpresaEstado.fromString(nuevoEstado),
        );
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Carga estadísticas de empresas
  Future<void> loadStats() async {
    try {
      _stats = await _repository.getEmpresaStats() as EmpresaStats;
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando stats: $e');
    }
  }

  /// Aplica filtros
  void setFilters({
    String? estado,
    String? municipio,
    String? search,
  }) {
    _estadoFilter = estado;
    _municipioFilter = municipio;
    _searchQuery = search;
    loadEmpresas(refresh: true);
  }

  /// Limpia filtros
  void clearFilters() {
    _estadoFilter = null;
    _municipioFilter = null;
    _searchQuery = null;
    loadEmpresas(refresh: true);
  }

  /// Selecciona una empresa
  void selectEmpresa(EmpresaTransporte? empresa) {
    _selectedEmpresa = empresa;
    notifyListeners();
  }

  /// Limpia el error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia todo el estado
  void reset() {
    _state = EmpresaProviderState.initial;
    _errorMessage = null;
    _empresas = [];
    _selectedEmpresa = null;
    _stats = null;
    _estadoFilter = null;
    _municipioFilter = null;
    _searchQuery = null;
    _currentPage = 1;
    _totalPages = 1;
    notifyListeners();
  }
}

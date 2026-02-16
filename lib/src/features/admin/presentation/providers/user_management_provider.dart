import 'package:flutter/foundation.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/manage_user_usecase.dart';

class AdminUserManagementProvider with ChangeNotifier {
  final GetUsersUseCase getUsersUseCase;
  final ManageUserUseCase manageUserUseCase;
  final int adminId;

  AdminUserManagementProvider({
    required this.getUsersUseCase,
    required this.manageUserUseCase,
    required this.adminId,
  });

  bool _isLoading = false;
  List<dynamic> _users = [];
  String? _errorMessage;
  int _currentPage = 1;
  final int _totalPages = 1;
  String? _currentFilter; // 'cliente', 'conductor', 'empresa', or null for all
  String? _searchQuery;
  bool _showInactive = false; // false = show active, true = show inactive

  bool get isLoading => _isLoading;
  List<dynamic> get users => _users;
  String? get errorMessage => _errorMessage;
  String? get currentFilter => _currentFilter;
  bool get showInactive => _showInactive;

  /// Cargar usuarios con filtros actuales
  Future<void> loadUsers({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _users = [];
    }

    _setLoading(true);

    try {
      print('Provider: Loading users for adminId: $adminId, query: $_searchQuery, filter: $_currentFilter, inactive: $_showInactive');
      final result = await getUsersUseCase(
        adminId: adminId,
        page: _currentPage,
        search: _searchQuery,
        tipoUsuario: _currentFilter,
        esActivo: !_showInactive, // When showInactive is true, we want es_activo = false
      );

      result.fold(
        (failure) => _setError(failure.toString()), // TODO: Better error message
        (data) {

          // Fix: The backend returns {data: {usuarios: [...]}}, so we need to access the nested keys
          // We check both data['data']['usuarios'] and data['usuarios'] to be safe
          List<dynamic> newUsers = [];
          if (data['data'] != null && data['data']['usuarios'] != null) {
            newUsers = data['data']['usuarios'];
          } else if (data['usuarios'] != null) {
            newUsers = data['usuarios'];
          }
          
          if (refresh) {
            _users = newUsers;
          } else {
            _users.addAll(newUsers);
          }
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Cambiar filtro de tipo de usuario
  void setFilter(String? filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      loadUsers(refresh: true);
    }
  }

  /// Buscar usuarios
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      // Debounce logic should be in UI or here with Timer
      loadUsers(refresh: true);
    }
  }

  /// Toggle showing active/inactive users
  void setShowInactive(bool showInactive) {
    if (_showInactive != showInactive) {
      _showInactive = showInactive;
      loadUsers(refresh: true);
    }
  }

  /// Actualizar estado de usuario (Activar/Desactivar)
  Future<bool> toggleUserStatus(int userId, bool currentStatus) async {
    final result = await manageUserUseCase.updateUser(
      adminId: 1,
      userId: userId,
      esActivo: !currentStatus,
    );

    return result.fold(
      (failure) {
        _setError("Error al actualizar estado");
        return false;
      },
      (success) {
        if (success) {
          // Actualizar lista localmente
          final index = _users.indexWhere((u) => u['id'] == userId);
          if (index != -1) {
            _users[index]['es_activo'] = !currentStatus ? 1 : 0;
            notifyListeners();
          }
        }
        return success;
      },
    );
  }

  /// Actualizar información completa del usuario
  Future<bool> updateUser({
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? tipoUsuario,
    int? empresaId,
    String? empresaNombre,
  }) async {
    _setLoading(true);
    
    print('Provider.updateUser - userId: $userId, nombre: $nombre, tipoUsuario: $tipoUsuario, empresaId: $empresaId');
    
    try {
      final result = await manageUserUseCase.updateUser(
        adminId: adminId,
        userId: userId,
        nombre: nombre,
        apellido: apellido,
        telefono: telefono,
        tipoUsuario: tipoUsuario,
        empresaId: empresaId,
      );

      return result.fold(
        (failure) {
          print('Provider.updateUser - Failure: $failure');
          _setError('Error al actualizar: ${failure.toString()}');
          return false;
        },
        (success) {
          print('Provider.updateUser - Success: $success');
          if (success) {
            // Update local list
            final index = _users.indexWhere((u) => u['id'] == userId);
            if (index != -1) {
              final updatedUser = Map<String, dynamic>.from(_users[index]);
              if (nombre != null) updatedUser['nombre'] = nombre;
              if (apellido != null) updatedUser['apellido'] = apellido;
              if (telefono != null) updatedUser['telefono'] = telefono;
              if (tipoUsuario != null) updatedUser['tipo_usuario'] = tipoUsuario;
              
              if (empresaId != null && empresaId > 0) {
                // Para conductores, empresa_id es obligatorio
                // Solo actualizar si se proporciona un ID válido
                updatedUser['empresa_id'] = empresaId;
              }
              if (empresaNombre != null) updatedUser['empresa_nombre'] = empresaNombre;
              
              _users[index] = updatedUser;
              notifyListeners();
            }
          }
          _setLoading(false);
          return success;
        },
      );
    } catch (e, stack) {
      print('Provider.updateUser - Exception: $e');
      print('Provider.updateUser - Stack: $stack');
      _setError('Error inesperado: $e');
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
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

import 'package:flutter/foundation.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/manage_user_usecase.dart';

class AdminUserManagementProvider with ChangeNotifier {
  final GetUsersUseCase getUsersUseCase;
  final ManageUserUseCase manageUserUseCase;

  AdminUserManagementProvider({
    required this.getUsersUseCase,
    required this.manageUserUseCase,
  });

  bool _isLoading = false;
  List<dynamic> _users = [];
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _currentFilter; // 'cliente', 'conductor', 'empresa', or null for all
  String? _searchQuery;

  bool get isLoading => _isLoading;
  List<dynamic> get users => _users;
  String? get errorMessage => _errorMessage;
  String? get currentFilter => _currentFilter;

  /// Cargar usuarios con filtros actuales
  Future<void> loadUsers({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _users = [];
    }

    _setLoading(true);

    try {
      final result = await getUsersUseCase(
        adminId: 1, // TODO: Obtener ID real del admin
        page: _currentPage,
        search: _searchQuery,
        tipoUsuario: _currentFilter,
      );

      result.fold(
        (failure) => _setError(failure.toString()), // TODO: Better error message
        (data) {
          final newUsers = data['usuarios'] ?? [];
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

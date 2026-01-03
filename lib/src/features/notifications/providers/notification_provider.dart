import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Estado de carga para el provider
enum NotificationLoadState { initial, loading, loaded, error }

/// Provider para gestionar el estado de las notificaciones
/// Sigue el patrón de la app con ChangeNotifier
class NotificationProvider extends ChangeNotifier {
  // Estado
  List<NotificationModel> _notifications = [];
  NotificationSettings? _settings;
  NotificationLoadState _loadState = NotificationLoadState.initial;
  String _errorMessage = '';
  int _unreadCount = 0;
  int _currentPage = 1;
  bool _hasMore = true;
  String _selectedFilter = 'all';
  int? _userId;
  
  // Timer para polling de nuevas notificaciones
  Timer? _pollingTimer;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  NotificationSettings? get settings => _settings;
  NotificationLoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loadState == NotificationLoadState.loading;
  bool get hasMore => _hasMore;
  String get selectedFilter => _selectedFilter;

  /// Lista filtrada de notificaciones
  List<NotificationModel> get filteredNotifications {
    if (_selectedFilter == 'all') return _notifications;
    if (_selectedFilter == 'unread') {
      return _notifications.where((n) => !n.leida).toList();
    }
    return _notifications.where((n) => n.tipo == _selectedFilter).toList();
  }

  /// Notificaciones no leídas
  List<NotificationModel> get unreadNotifications =>
      _notifications.where((n) => !n.leida).toList();

  /// Inicializa el provider con el ID del usuario
  void initialize(int userId) {
    _userId = userId;
    loadNotifications(userId: userId, refresh: true);
    loadSettings(userId: userId);
    _startPolling(userId);
  }

  /// Carga las notificaciones del usuario
  Future<void> loadNotifications({
    required int userId,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (_loadState == NotificationLoadState.loading && !refresh) return;

    _loadState = NotificationLoadState.loading;
    if (refresh) _notifications = [];
    notifyListeners();

    final result = await NotificationService.getNotifications(
      userId: userId,
      page: _currentPage,
      soloNoLeidas: _selectedFilter == 'unread',
    );

    if (result['success'] == true) {
      final notificaciones = result['notificaciones'] as List<NotificationModel>;
      
      if (refresh || _currentPage == 1) {
        _notifications = notificaciones;
      } else {
        _notifications.addAll(notificaciones);
      }

      _unreadCount = result['no_leidas'] ?? 0;

      // Verificar si hay más páginas
      final pagination = result['pagination'];
      if (pagination != null) {
        _hasMore = _currentPage < (pagination['total_pages'] ?? 1);
      } else {
        _hasMore = notificaciones.isNotEmpty && notificaciones.length >= 20;
      }

      _loadState = NotificationLoadState.loaded;
      _errorMessage = '';
    } else {
      _loadState = NotificationLoadState.error;
      _errorMessage = result['error'] ?? 'Error al cargar notificaciones';
    }

    notifyListeners();
  }

  /// Carga más notificaciones (paginación)
  Future<void> loadMore({required int userId}) async {
    if (!_hasMore || _loadState == NotificationLoadState.loading) return;
    _currentPage++;
    await loadNotifications(userId: userId);
  }

  /// Actualiza solo el conteo de no leídas (para el badge)
  Future<void> refreshUnreadCount({required int userId}) async {
    _unreadCount = await NotificationService.getUnreadCount(userId: userId);
    notifyListeners();
  }

  /// Marca una notificación como leída
  Future<bool> markAsRead({
    required int userId,
    required int notificationId,
  }) async {
    final result = await NotificationService.markAsRead(
      userId: userId,
      notificationId: notificationId,
    );

    if (result['success'] == true) {
      // Actualizar estado local
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(
          leida: true,
          leidaEn: DateTime.now(),
        );
      }
      _unreadCount = result['no_leidas'] ?? _unreadCount;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Marca todas las notificaciones como leídas
  Future<bool> markAllAsRead({required int userId}) async {
    final result = await NotificationService.markAsRead(
      userId: userId,
      markAll: true,
    );

    if (result['success'] == true) {
      // Actualizar estado local
      _notifications = _notifications.map((n) => n.copyWith(
        leida: true,
        leidaEn: DateTime.now(),
      )).toList();
      _unreadCount = 0;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Elimina una notificación
  Future<bool> deleteNotification({
    required int userId,
    required int notificationId,
  }) async {
    final result = await NotificationService.deleteNotification(
      userId: userId,
      notificationId: notificationId,
    );

    if (result['success'] == true) {
      // Remover de la lista local
      _notifications.removeWhere((n) => n.id == notificationId);
      _unreadCount = result['no_leidas'] ?? _unreadCount;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Elimina todas las notificaciones
  Future<bool> deleteAllNotifications({required int userId}) async {
    final result = await NotificationService.deleteNotification(
      userId: userId,
      deleteAll: true,
    );

    if (result['success'] == true) {
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Carga la configuración de notificaciones
  Future<void> loadSettings({required int userId}) async {
    _settings = await NotificationService.getSettings(userId: userId);
    notifyListeners();
  }

  /// Actualiza un ajuste de notificaciones
  Future<bool> updateSetting({
    required int userId,
    required String key,
    required dynamic value,
  }) async {
    final result = await NotificationService.updateSettings(
      userId: userId,
      settings: {key: value},
    );

    if (result['success'] == true) {
      _settings = result['settings'] as NotificationSettings;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Cambia el filtro de notificaciones
  void setFilter(String filter, {required int userId}) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      _notifications = [];
      loadNotifications(userId: userId, refresh: true);
    }
  }

  /// Refresca todo
  Future<void> refresh({required int userId}) async {
    await Future.wait([
      loadNotifications(userId: userId, refresh: true),
      refreshUnreadCount(userId: userId),
    ]);
  }

  /// Inicia el polling para nuevas notificaciones
  void _startPolling(int userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshUnreadCount(userId: userId),
    );
  }

  /// Detiene el polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Limpia el estado
  void clear() {
    _notifications = [];
    _settings = null;
    _loadState = NotificationLoadState.initial;
    _unreadCount = 0;
    _currentPage = 1;
    _hasMore = true;
    _selectedFilter = 'all';
    stopPolling();
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

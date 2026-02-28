import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Estado de carga para el provider
enum NotificationLoadState { initial, loading, loaded, error }

/// Provider para gestionar el estado de las notificaciones
/// Sigue el patrón de la app con ChangeNotifier
class NotificationProvider extends ChangeNotifier {
  static const Set<String> _tripTypes = {
    'trip_accepted',
    'trip_cancelled',
    'trip_completed',
    'driver_arrived',
    'driver_waiting',
  };

  static const Set<String> _paymentTypes = {
    'payment_received',
    'payment_pending',
  };

  static const Set<String> _documentTypes = {
    'document_approved',
    'document_rejected',
    'driver_document_update',
  };

  static const Set<String> _chatTypes = {
    'chat_message',
  };

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

  // Eliminaciones pendientes con ventana de deshacer
  final Map<int, _PendingNotificationDeletion> _pendingDeletions = {};
  _PendingDeleteAll? _pendingDeleteAll;
  
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
    if (_selectedFilter == 'trips') {
      return _notifications.where((n) => _tripTypes.contains(n.tipo)).toList();
    }
    if (_selectedFilter == 'payments') {
      return _notifications.where((n) => _paymentTypes.contains(n.tipo)).toList();
    }
    if (_selectedFilter == 'documents') {
      return _notifications.where((n) => _documentTypes.contains(n.tipo)).toList();
    }
    if (_selectedFilter == 'chat') {
      return _notifications.where((n) => _chatTypes.contains(n.tipo)).toList();
    }
    if (_selectedFilter == 'promo') {
      return _notifications.where((n) => n.tipo == 'promo').toList();
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
    if (_pendingDeleteAll != null) {
      return false;
    }

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

  /// Elimina una notificación de la UI y espera una ventana para confirmar
  /// el borrado en backend. Permite deshacer dentro de la ventana.
  bool stageDeleteNotification({
    required int userId,
    required NotificationModel notification,
    Duration gracePeriod = const Duration(seconds: 4),
  }) {
    if (_pendingDeleteAll != null) {
      return false;
    }

    final existingPending = _pendingDeletions[notification.id];
    if (existingPending != null) {
      return true;
    }

    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index == -1) {
      return false;
    }

    _notifications.removeAt(index);
    if (!notification.leida && _unreadCount > 0) {
      _unreadCount--;
    }

    final timer = Timer(gracePeriod, () {
      _commitPendingDelete(userId: userId, notificationId: notification.id);
    });

    _pendingDeletions[notification.id] = _PendingNotificationDeletion(
      notification: notification,
      originalIndex: index,
      timer: timer,
    );

    notifyListeners();
    return true;
  }

  /// Elimina todas de la UI y espera una ventana para confirmar el borrado
  /// en backend. Permite deshacer dentro de la ventana.
  bool stageDeleteAllNotifications({
    required int userId,
    Duration gracePeriod = const Duration(seconds: 4),
  }) {
    if (_pendingDeleteAll != null) {
      return false;
    }

    _restorePendingSingleDeletes();

    if (_notifications.isEmpty) {
      return false;
    }

    final snapshotNotifications = List<NotificationModel>.from(_notifications);
    final snapshotUnread = _unreadCount;

    _notifications = [];
    _unreadCount = 0;

    final timer = Timer(gracePeriod, () {
      _commitPendingDeleteAll(userId: userId);
    });

    _pendingDeleteAll = _PendingDeleteAll(
      notificationsSnapshot: snapshotNotifications,
      unreadCountSnapshot: snapshotUnread,
      timer: timer,
    );

    notifyListeners();
    return true;
  }

  /// Revierte la eliminación masiva pendiente.
  bool undoDeleteAllNotifications() {
    final pending = _pendingDeleteAll;
    if (pending == null) return false;

    pending.timer.cancel();
    _pendingDeleteAll = null;

    _notifications = List<NotificationModel>.from(pending.notificationsSnapshot);
    _unreadCount = pending.unreadCountSnapshot;
    notifyListeners();
    return true;
  }

  /// Revierte una eliminación pendiente dentro de la ventana de gracia.
  bool undoDeleteNotification({
    required int notificationId,
  }) {
    final pending = _pendingDeletions.remove(notificationId);
    if (pending == null) return false;

    pending.timer.cancel();

    final safeIndex = pending.originalIndex.clamp(0, _notifications.length);
    _notifications.insert(safeIndex, pending.notification);
    if (!pending.notification.leida) {
      _unreadCount++;
    }

    notifyListeners();
    return true;
  }

  Future<void> _commitPendingDelete({
    required int userId,
    required int notificationId,
  }) async {
    final pending = _pendingDeletions.remove(notificationId);
    if (pending == null) return;

    final result = await NotificationService.deleteNotification(
      userId: userId,
      notificationId: notificationId,
    );

    if (result['success'] == true) {
      _unreadCount = result['no_leidas'] ?? _unreadCount;
      notifyListeners();
      return;
    }

    final safeIndex = pending.originalIndex.clamp(0, _notifications.length);
    _notifications.insert(safeIndex, pending.notification);
    if (!pending.notification.leida) {
      _unreadCount++;
    }
    notifyListeners();
  }

  Future<void> _commitPendingDeleteAll({
    required int userId,
  }) async {
    final pending = _pendingDeleteAll;
    if (pending == null) return;

    _pendingDeleteAll = null;

    final result = await NotificationService.deleteNotification(
      userId: userId,
      deleteAll: true,
    );

    if (result['success'] == true) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    _notifications = List<NotificationModel>.from(pending.notificationsSnapshot);
    _unreadCount = pending.unreadCountSnapshot;
    notifyListeners();
  }

  void _restorePendingSingleDeletes() {
    if (_pendingDeletions.isEmpty) return;

    final pendingItems = _pendingDeletions.values.toList()
      ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex));

    for (final pending in pendingItems) {
      pending.timer.cancel();
      final safeIndex = pending.originalIndex.clamp(0, _notifications.length);
      _notifications.insert(safeIndex, pending.notification);
      if (!pending.notification.leida) {
        _unreadCount++;
      }
    }

    _pendingDeletions.clear();
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
    _pendingDeleteAll?.timer.cancel();
    _pendingDeleteAll = null;
    for (final pending in _pendingDeletions.values) {
      pending.timer.cancel();
    }
    _pendingDeletions.clear();
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
    _pendingDeleteAll?.timer.cancel();
    _pendingDeleteAll = null;
    for (final pending in _pendingDeletions.values) {
      pending.timer.cancel();
    }
    _pendingDeletions.clear();
    stopPolling();
    super.dispose();
  }
}

class _PendingNotificationDeletion {
  final NotificationModel notification;
  final int originalIndex;
  final Timer timer;

  const _PendingNotificationDeletion({
    required this.notification,
    required this.originalIndex,
    required this.timer,
  });
}

class _PendingDeleteAll {
  final List<NotificationModel> notificationsSnapshot;
  final int unreadCountSnapshot;
  final Timer timer;

  const _PendingDeleteAll({
    required this.notificationsSnapshot,
    required this.unreadCountSnapshot,
    required this.timer,
  });
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../company/presentation/screens/company_conductores_documentos_screen.dart';
import '../../../company/presentation/screens/company_commissions_screen.dart';
import '../../../conductor/presentation/screens/conductor_commissions_screen.dart';
import '../../../../routes/route_names.dart';
import '../../../../theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../widgets/notification_widgets.dart';

/// Pantalla de notificaciones del usuario
/// Muestra todas las notificaciones con filtros y acciones
class NotificationsScreen extends StatelessWidget {
  final int userId;
  final Map<String, dynamic>? currentUser;
  final String? userType;

  const NotificationsScreen({
    super.key,
    required this.userId,
    this.currentUser,
    this.userType,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationProvider()..initialize(userId),
      child: _NotificationsContent(
        userId: userId,
        currentUser: currentUser,
        userType: userType,
      ),
    );
  }
}

class _NotificationsContent extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? currentUser;
  final String? userType;

  const _NotificationsContent({
    required this.userId,
    this.currentUser,
    this.userType,
  });

  @override
  State<_NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends State<_NotificationsContent>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    
    _scrollController = ScrollController()..addListener(_onScroll);
    
    _headerController.forward();
  }

  void _onScroll() {
    // Cargar más notificaciones al llegar al final
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<NotificationProvider>();
      if (provider.hasMore && !provider.isLoading) {
        provider.loadMore(userId: widget.userId);
      }
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showThemedSnackBar({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedBackground =
        backgroundColor ??
        (isDark
            ? AppColors.darkCard.withValues(alpha: 0.95)
            : AppColors.lightTextPrimary.withValues(alpha: 0.95));

    final contrastBrightness = ThemeData.estimateBrightnessForColor(
      resolvedBackground,
    );
    final foregroundColor = contrastBrightness == Brightness.dark
        ? Colors.white
        : AppColors.lightTextPrimary;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: resolvedBackground,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.primary,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final normalizedUserType = widget.userType?.toLowerCase();
    final isAdmin = normalizedUserType == 'admin' || normalizedUserType == 'administrador';
    final isCompany = normalizedUserType == 'empresa' || normalizedUserType == 'company';
    final isConductor = normalizedUserType == 'conductor';
    final visibleFilterKeys = isAdmin
      ? const ['all', 'unread', 'documents', 'payments', 'system']
      : isCompany
      ? const ['all', 'unread', 'payments', 'documents']
      : isConductor
        ? const ['all', 'unread', 'trips', 'payments', 'documents']
        : const ['all', 'unread', 'trips', 'payments', 'documents', 'chat', 'promo'];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Marcar todas como leídas al salir de la pantalla
          context.read<NotificationProvider>().markAllAsRead(userId: widget.userId);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
      body: SafeArea(
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                // Header
                _buildHeader(context, provider, isDark, surfaceColor),
                
                // Filtros
                const SizedBox(height: 12),
                NotificationFilters(
                  selectedFilter: provider.selectedFilter,
                  visibleFilterKeys: visibleFilterKeys,
                  onFilterChanged: (filter) {
                    provider.setFilter(filter, userId: widget.userId);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                
                // Lista de notificaciones
                Expanded(
                  child: _buildNotificationList(provider, isDark),
                ),
              ],
            );
          },
        ),
      ),
    ));
  }

  Widget _buildHeader(
    BuildContext context,
    NotificationProvider provider,
    bool isDark,
    Color surfaceColor,
  ) {
    return FadeTransition(
      opacity: _headerAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(_headerAnimation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Expanded Left Pill (Title + Back)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Back Button (Inner Circle)
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title
                          Expanded(
                            child: Text(
                              'Notificaciones',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (provider.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                provider.unreadCount.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right Circle (Menu)
              ClipOval(
                child: Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) => _handleMenuAction(value, provider),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Configuración'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete_all',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Eliminar todas',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(NotificationProvider provider, bool isDark) {
    final notifications = provider.filteredNotifications;

    if (provider.loadState == NotificationLoadState.loading &&
        provider.notifications.isEmpty) {
      return NotificationLoadingShimmer(isDark: isDark);
    }

    if (provider.loadState == NotificationLoadState.error &&
        provider.notifications.isEmpty) {
      return _buildErrorState(provider, isDark);
    }

    if (notifications.isEmpty) {
      return NotificationEmptyState(
        filter: provider.selectedFilter,
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(userId: widget.userId),
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: notifications.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == notifications.length) {
            return _buildLoadingMore(isDark);
          }

          final notification = notifications[index];
          return NotificationCard(
            notification: notification,
            showDivider: index < notifications.length - 1,
            onTap: () => _handleNotificationTap(notification, provider),
            onDismiss: () => _handleNotificationDismiss(notification, provider),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(NotificationProvider provider, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.refresh(userId: widget.userId),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMore(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.primary,
      ),
    );
  }

  void _handleNotificationTap(
    NotificationModel notification,
    NotificationProvider provider,
  ) async {
    // Marcar como leída si no lo está
    if (!notification.leida) {
      await provider.markAsRead(
        userId: widget.userId,
        notificationId: notification.id,
      );
    }

    // Navegar según el tipo de notificación
    final handled = await _navigateToReference(notification);
    if (!handled && mounted) {
      _showThemedSnackBar(
        message: 'Esta notificación no tiene una vista detallada disponible.',
      );
    }
  }

  void _handleNotificationDismiss(
    NotificationModel notification,
    NotificationProvider provider,
  ) async {
    final staged = provider.stageDeleteNotification(
      userId: widget.userId,
      notification: notification,
    );

    if (!staged) return;

    if (mounted) {
      _showThemedSnackBar(
        message: 'Notificación eliminada',
        duration: const Duration(seconds: 4),
        actionLabel: 'Deshacer',
        onAction: () {
          provider.undoDeleteNotification(notificationId: notification.id);
        },
      );
    }
  }

  void _handleMenuAction(String action, NotificationProvider provider) {
    switch (action) {
      case 'settings':
        _showSettingsSheet(provider);
        break;
      case 'delete_all':
        _showDeleteAllConfirmation(provider);
        break;
    }
  }

  void _showSettingsSheet(NotificationProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationSettingsSheet(
        userId: widget.userId,
        userType: widget.userType,
        settings: provider.settings,
        onSettingChanged: (key, value) {
          provider.updateSetting(
            userId: widget.userId,
            key: key,
            value: value,
          );
        },
      ),
    );
  }

  void _showDeleteAllConfirmation(NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar todas'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar todas las notificaciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final staged = provider.stageDeleteAllNotifications(
                userId: widget.userId,
              );
              if (!mounted) return;

              if (!staged) {
                _showThemedSnackBar(
                  message: 'No hay notificaciones para eliminar.',
                );
                return;
              }

              _showThemedSnackBar(
                message: 'Todas las notificaciones eliminadas',
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 4),
                actionLabel: 'Deshacer',
                onAction: provider.undoDeleteAllNotifications,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  Future<bool> _navigateToReference(NotificationModel notification) async {
    final referenceType = notification.referenciaTipo;

    final normalizedUserType = (widget.userType ?? widget.currentUser?['tipo_usuario']?.toString())
        ?.toLowerCase();

    final reportId = notification.referenciaId ?? _asInt(notification.data['reporte_id']);
    final conductorId = _asInt(notification.data['conductor_id']);

    Future<bool> openConductorCommissions() async {
      if (normalizedUserType != 'conductor') return false;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConductorCommissionsScreen(
            conductorId: _asInt(widget.currentUser?['id']) ?? widget.userId,
            conductorUser: widget.currentUser,
          ),
        ),
      );
      return true;
    }

    if (referenceType == null) {
      if (notification.tipo.startsWith('debt_payment_') ||
          notification.tipo == 'debt_payment_reminder' ||
          notification.tipo == 'debt_payment_mandatory') {
        return openConductorCommissions();
      }
      return false;
    }

    // Navegar según el tipo de referencia
    switch (referenceType) {
      case 'pago_comision_reporte':
        if (normalizedUserType == 'empresa' && widget.currentUser != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompanyCommissionsScreen(
                user: widget.currentUser!,
                initialConductorId: conductorId,
                initialReportId: reportId,
              ),
            ),
          );
          return true;
        }

        return openConductorCommissions();

      case 'deuda_comision':
        return openConductorCommissions();

      case 'conductor_solicitud':
      case 'documento_conductor':
      case 'conductor':
        if (normalizedUserType == 'empresa' && widget.currentUser != null) {
          final companyId = _asInt(widget.currentUser?['empresa_id']) ??
              _asInt(widget.currentUser?['id']);
          if (companyId == null || companyId <= 0) {
            return false;
          }

          final initialUserId = conductorId ??
              (referenceType == 'conductor' ? notification.referenciaId : null);

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompanyConductoresDocumentosScreen(
                user: widget.currentUser!,
                empresaId: companyId,
                initialUserId: initialUserId,
              ),
            ),
          );
          return true;
        }
        return false;

      case 'pago':
        return openConductorCommissions();

      default:
        if (notification.tipo.startsWith('debt_payment_') ||
            referenceType == 'deuda_comision') {
          return openConductorCommissions();
        }
        return false;
    }
  }
}

/// Sheet de configuración de notificaciones
class _NotificationSettingsSheet extends StatefulWidget {
  final int userId;
  final String? userType;
  final NotificationSettings? settings;
  final Function(String key, dynamic value) onSettingChanged;

  const _NotificationSettingsSheet({
    required this.userId,
    this.userType,
    required this.settings,
    required this.onSettingChanged,
  });

  @override
  State<_NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<_NotificationSettingsSheet> {
  late NotificationSettings _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = widget.settings ?? NotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final normalizedUserType = widget.userType?.toLowerCase();
    final isAdmin = normalizedUserType == 'admin' || normalizedUserType == 'administrador';
    final isCompany = normalizedUserType == 'empresa' || normalizedUserType == 'company';
    final isConductor = normalizedUserType == 'conductor';

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Título
          Text(
            'Configuración de notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Opciones
          _buildSwitch(
            'Notificaciones push',
            'Recibir alertas en tu dispositivo',
            Icons.notifications_active_rounded,
            _localSettings.pushEnabled,
            (value) {
              setState(() {
                _localSettings = _localSettings.copyWith(pushEnabled: value);
              });
              widget.onSettingChanged('push_enabled', value);
            },
            isDark,
          ),

          if (!isCompany && !isAdmin)
            _buildSwitch(
              'Viajes',
              'Actualizaciones sobre tus viajes',
              Icons.directions_car_rounded,
              _localSettings.notifViajes,
              (value) {
                setState(() {
                  _localSettings = _localSettings.copyWith(notifViajes: value);
                });
                widget.onSettingChanged('notif_viajes', value);
              },
              isDark,
            ),

          _buildSwitch(
            'Pagos',
            isCompany
                ? 'Comprobantes y movimientos de pago de conductores'
                : 'Confirmaciones y recibos de pago',
            Icons.payment_rounded,
            _localSettings.notifPagos,
            (value) {
              setState(() {
                _localSettings = _localSettings.copyWith(notifPagos: value);
              });
              widget.onSettingChanged('notif_pagos', value);
            },
            isDark,
          ),

          if (isCompany || isConductor || isAdmin)
            _buildSwitch(
              'Documentos y estado',
              isCompany
                  ? 'Cambios en documentos y solicitudes de vinculación'
                  : isAdmin
                      ? 'Solicitudes empresariales y validaciones pendientes'
                  : 'Cambios de estado documental y validaciones',
              Icons.description_rounded,
              _localSettings.notifSistema,
              (value) {
                setState(() {
                  _localSettings = _localSettings.copyWith(notifSistema: value);
                });
                widget.onSettingChanged('notif_sistema', value);
              },
              isDark,
            )
          else
            _buildSwitch(
              'Promociones',
              'Ofertas y descuentos especiales',
              Icons.local_offer_rounded,
              _localSettings.notifPromociones,
              (value) {
                setState(() {
                  _localSettings = _localSettings.copyWith(notifPromociones: value);
                });
                widget.onSettingChanged('notif_promociones', value);
              },
              isDark,
            ),

          if (!isCompany && !isConductor && !isAdmin)
            _buildSwitch(
              'Mensajes',
              'Notificaciones del chat',
              Icons.chat_rounded,
              _localSettings.notifChat,
              (value) {
                setState(() {
                  _localSettings = _localSettings.copyWith(notifChat: value);
                });
                widget.onSettingChanged('notif_chat', value);
              },
              isDark,
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

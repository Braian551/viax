import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../widgets/notification_widgets.dart';

/// Pantalla de notificaciones del usuario
/// Muestra todas las notificaciones con filtros y acciones
class NotificationsScreen extends StatelessWidget {
  final int userId;

  const NotificationsScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationProvider()..initialize(userId),
      child: _NotificationsContent(userId: userId),
    );
  }
}

class _NotificationsContent extends StatefulWidget {
  final int userId;

  const _NotificationsContent({required this.userId});

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
    
    // Marcar todas como leídas al entrar (comportamiento estilo app)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pequeño delay para que la UI cargue primero
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          context.read<NotificationProvider>().markAllAsRead(userId: widget.userId);
        }
      });
    });
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Scaffold(
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
    );
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Botón atrás
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              
              // Título
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (provider.unreadCount > 0)
                      Text(
                        '${provider.unreadCount} sin leer',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Acciones (Eliminado botón Leer todo)
              
              // Menú de opciones
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
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
                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Eliminar todas', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(NotificationProvider provider, bool isDark) {
    if (provider.loadState == NotificationLoadState.loading &&
        provider.notifications.isEmpty) {
      return NotificationLoadingShimmer(isDark: isDark);
    }

    if (provider.loadState == NotificationLoadState.error &&
        provider.notifications.isEmpty) {
      return _buildErrorState(provider, isDark);
    }

    if (provider.notifications.isEmpty) {
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
        itemCount: provider.notifications.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.notifications.length) {
            return _buildLoadingMore(isDark);
          }

          final notification = provider.notifications[index];
          return NotificationCard(
            notification: notification,
            showDivider: index < provider.notifications.length - 1,
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
    if (notification.referenciaTipo != null && notification.referenciaId != null) {
      _navigateToReference(notification);
    }
  }

  void _handleNotificationDismiss(
    NotificationModel notification,
    NotificationProvider provider,
  ) async {
    await provider.deleteNotification(
      userId: widget.userId,
      notificationId: notification.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notificación eliminada'),
          backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: AppColors.primary,
            onPressed: () {
              // Aquí se podría implementar deshacer si se guarda el estado
              provider.refresh(userId: widget.userId);
            },
          ),
        ),
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
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todas'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar todas las notificaciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.deleteAllNotifications(userId: widget.userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Todas las notificaciones eliminadas'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _navigateToReference(NotificationModel notification) {
    // Navegar según el tipo de referencia
    switch (notification.referenciaTipo) {
      case 'viaje':
        // Navigator.pushNamed(context, '/trip/${notification.referenciaId}');
        break;
      case 'pago':
        // Navigator.pushNamed(context, '/payment/${notification.referenciaId}');
        break;
      case 'disputa':
        // Navigator.pushNamed(context, '/dispute/${notification.referenciaId}');
        break;
    }
  }
}

/// Sheet de configuración de notificaciones
class _NotificationSettingsSheet extends StatefulWidget {
  final int userId;
  final NotificationSettings? settings;
  final Function(String key, dynamic value) onSettingChanged;

  const _NotificationSettingsSheet({
    required this.userId,
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
            'Confirmaciones y recibos de pago',
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
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

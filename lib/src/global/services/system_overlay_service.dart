import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Servicio que maneja el overlay flotante del sistema.
/// 
/// Este overlay aparece fuera de la app cuando hay un viaje en curso,
/// permitiendo al usuario volver a la app con un solo toque.
/// 
/// Solo funciona en Android, ya que iOS no permite overlays del sistema.
class SystemOverlayService {
  // Singleton
  static final SystemOverlayService _instance = SystemOverlayService._internal();
  factory SystemOverlayService() => _instance;
  SystemOverlayService._internal() {
    _setupMethodCallHandler();
  }

  static const MethodChannel _channel = MethodChannel('com.example.viax/floating_overlay');

  // Estado del overlay
  bool _isOverlayVisible = false;
  bool get isOverlayVisible => _isOverlayVisible;

  // Callback cuando se presiona el overlay para navegar
  Function(String userRole, int solicitudId)? _onNavigateToTrip;
  
  // Callback cuando el usuario elimina el overlay
  VoidCallback? _onOverlayRemoved;

  // Datos del viaje actual (para referencia interna)
  // ignore: unused_field - mantenido para debugging futuro
  String? _currentUserRole;
  // ignore: unused_field - mantenido para debugging futuro
  int? _currentSolicitudId;

  /// Configura el handler para recibir llamadas desde nativo
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'navigateToTrip':
          final userRole = call.arguments['userRole'] as String?;
          final solicitudId = call.arguments['solicitudId'] as int?;
          if (userRole != null && solicitudId != null) {
            debugPrint('🚗 [SystemOverlay] Navegando al viaje: $solicitudId');
            _onNavigateToTrip?.call(userRole, solicitudId);
          }
          break;
        case 'onOverlayRemoved':
          debugPrint('🗑️ [SystemOverlay] Overlay eliminado por el usuario');
          _isOverlayVisible = false;
          _currentUserRole = null;
          _currentSolicitudId = null;
          _onOverlayRemoved?.call();
          break;
      }
    });
  }

  /// Configura el callback para navegación desde el overlay
  void setNavigationCallback(Function(String userRole, int solicitudId) callback) {
    _onNavigateToTrip = callback;
  }

  /// Configura el callback cuando el usuario elimina el overlay
  void setOverlayRemovedCallback(VoidCallback callback) {
    _onOverlayRemoved = callback;
  }

  /// Verifica si la app tiene permiso para mostrar overlays
  Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SystemOverlay] Error verificando permiso: ${e.message}');
      return false;
    }
  }

  /// Solicita permiso para mostrar overlays.
  /// Retorna true si el permiso fue concedido.
  Future<bool> requestOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SystemOverlay] Error solicitando permiso: ${e.message}');
      return false;
    }
  }

  /// Muestra el overlay flotante fuera de la app.
  /// 
  /// [userRole] - 'cliente' o 'conductor'
  /// [solicitudId] - ID de la solicitud del viaje
  Future<bool> showOverlay({
    required String userRole,
    required int solicitudId,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('📱 [SystemOverlay] iOS no soporta overlays del sistema');
      return false;
    }

    // Verificar permiso primero
    final hasPermission = await hasOverlayPermission();
    if (!hasPermission) {
      debugPrint('⚠️ [SystemOverlay] No hay permiso para overlay');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('showOverlay', {
        'userRole': userRole,
        'solicitudId': solicitudId,
      });
      
      _isOverlayVisible = result ?? false;
      if (_isOverlayVisible) {
        _currentUserRole = userRole;
        _currentSolicitudId = solicitudId;
        debugPrint('✅ [SystemOverlay] Overlay mostrado para viaje: $solicitudId');
      }
      
      return _isOverlayVisible;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SystemOverlay] Error mostrando overlay: ${e.message}');
      return false;
    }
  }

  /// Oculta el overlay flotante
  Future<bool> hideOverlay() async {
    if (!Platform.isAndroid) return true;
    if (!_isOverlayVisible) return true;

    try {
      final result = await _channel.invokeMethod<bool>('hideOverlay');
      _isOverlayVisible = false;
      _currentUserRole = null;
      _currentSolicitudId = null;
      debugPrint('🗑️ [SystemOverlay] Overlay ocultado');
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SystemOverlay] Error ocultando overlay: ${e.message}');
      return false;
    }
  }

  /// Muestra un diálogo para solicitar permiso de overlay
  Future<bool> showPermissionDialog(BuildContext context) async {
    if (!Platform.isAndroid) return false;

    final hasPermission = await hasOverlayPermission();
    if (hasPermission) return true;

    // Verificar si el context sigue válido después de la llamada async
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_in_picture_alt, color: Color(0xFF2196F3)),
            SizedBox(width: 12),
            Text('Permiso requerido'),
          ],
        ),
        content: const Text(
          'Para mostrar el botón flotante cuando salgas de la app '
          'durante un viaje, necesitamos permiso para mostrar '
          'contenido sobre otras aplicaciones.\n\n'
          '¿Deseas activar este permiso?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Activar'),
          ),
        ],
      ),
    );

    if (result == true) {
      return await requestOverlayPermission();
    }
    return false;
  }

  /// Limpia los recursos
  void dispose() {
    _onNavigateToTrip = null;
    _onOverlayRemoved = null;
  }
}

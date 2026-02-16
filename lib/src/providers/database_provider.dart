import 'package:flutter/material.dart';
import 'dart:convert';
import '../global/config/api_config.dart';
import '../core/network/network_request_executor.dart';

class DatabaseProvider with ChangeNotifier {
  // Cambiado: ahora usa API REST en lugar de conexiÃ³n MySQL directa
  bool _isConnected = false;
  String _errorMessage = '';

  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();

  Future<void> initializeDatabase() async {
    try {
      // Verificar conexión con el backend de Railway
      final result = await _network.getJson(
        url: Uri.parse('${ApiConfig.baseUrl}/verify_system_json.php'),
        headers: {'Content-Type': 'application/json'},
        timeout: const Duration(seconds: 10),
      );

      if (!result.success || result.json == null) {
        throw Exception(result.error?.userMessage ?? 'No se pudo validar la conexión con el backend.');
      }

      final data = result.json!;
      if (data['status'] == 'success' && data['database'] == 'connected') {
        _isConnected = true;
        _errorMessage = '';
        print('✅ Conexión con backend verificada correctamente');
      } else {
        throw Exception('Backend respondió, pero no confirmó conexión de base de datos.');
      }

      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'No se pudo conectar con el backend. Verifica tu internet e inténtalo nuevamente.';
      print('❌ Error al conectar con backend: $e');
      notifyListeners();
      // Don't rethrow to prevent app crash
    }
  }

  Future<void> closeConnection() async {
    // Para API REST, no hay conexión que cerrar
    _isConnected = false;
    _errorMessage = '';
    notifyListeners();
  }
}

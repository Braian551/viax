import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../global/config/api_config.dart';

class DatabaseProvider with ChangeNotifier {
  // Cambiado: ahora usa API REST en lugar de conexiÃ³n MySQL directa
  bool _isConnected = false;
  String _errorMessage = '';

  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;

  Future<void> initializeDatabase() async {
    try {
      // Verificar conexión con el backend de Railway
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/verify_system_json.php'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['database'] == 'connected') {
          _isConnected = true;
          _errorMessage = '';
          print('✅ Conexión con backend verificada correctamente');
        } else {
          throw Exception('Backend respondió pero base de datos no conectada');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }

      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Error al conectar con el backend: $e';
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

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viax/src/core/error/exceptions.dart';
import 'user_local_datasource.dart';

/// ImplementaciÃ³n del Datasource Local usando SharedPreferences
/// 
/// RESPONSABILIDADES:
/// - Guardar/recuperar sesiones usando SharedPreferences
/// - Serializar/deserializar JSON
/// - Manejar errores de almacenamiento local
class UserLocalDataSourceImpl implements UserLocalDataSource {
  static const String _legacySessionKey = 'viax_user_session';
  static const String _legacyUserEmailKey = 'viax_user_email';
  static const String _legacyUserIdKey = 'viax_user_id';
  static const String _legacyUserTypeKey = 'viax_user_type';

  static const String _sessionKey = 'viax_user_session';
  static const String _userEmailKey = 'viax_user_email';
  static const String _userIdKey = 'viax_user_id';
  static const String _userTypeKey = 'viax_user_type';

  final SharedPreferences sharedPreferences;

  UserLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> saveSession(Map<String, dynamic> sessionData) async {
    try {
      // Guardar sesiÃ³n completa como JSON
      final sessionJson = jsonEncode(sessionData);
      await sharedPreferences.setString(_sessionKey, sessionJson);

      // TambiÃ©n guardar campos individuales para compatibilidad
      // con cÃ³digo legacy (UserService)
      if (sessionData.containsKey('user')) {
        final user = sessionData['user'] as Map<String, dynamic>;
        
        if (user.containsKey('email')) {
          await sharedPreferences.setString(
            _userEmailKey,
            user['email'].toString(),
          );
        }
        
        if (user.containsKey('id')) {
          final userId = user['id'] is int 
              ? user['id'] 
              : int.tryParse(user['id'].toString()) ?? 0;
          await sharedPreferences.setInt(_userIdKey, userId);
        }
        
        if (user.containsKey('tipo_usuario')) {
          await sharedPreferences.setString(
            _userTypeKey,
            user['tipo_usuario'].toString(),
          );
        }
      }
    } catch (e) {
      throw CacheException('Error al guardar sesiÃ³n: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>?> getSavedSession() async {
    try {
      String? sessionJson = sharedPreferences.getString(_sessionKey);

      // MigraciÃ³n automÃ¡tica desde legacy si no existe nueva clave
      if (sessionJson == null || sessionJson.isEmpty) {
        final legacySession = sharedPreferences.getString(_legacySessionKey);
        if (legacySession != null && legacySession.isNotEmpty) {
          // Guardar bajo nueva clave y eliminar legacy
          await sharedPreferences.setString(_sessionKey, legacySession);
          await sharedPreferences.remove(_legacySessionKey);
          sessionJson = legacySession;
        }
      }
      
      if (sessionJson != null && sessionJson.isNotEmpty) {
        return jsonDecode(sessionJson) as Map<String, dynamic>;
      }

      // Reconstruir desde campos individuales (con migraciÃ³n)
      String? email = sharedPreferences.getString(_userEmailKey);
      int? id = sharedPreferences.getInt(_userIdKey);
      String? tipoUsuario = sharedPreferences.getString(_userTypeKey);

      if (email == null && id == null) {
        final legacyEmail = sharedPreferences.getString(_legacyUserEmailKey);
        final legacyId = sharedPreferences.getInt(_legacyUserIdKey);
        final legacyTipo = sharedPreferences.getString(_legacyUserTypeKey);

        if (legacyEmail != null || legacyId != null || legacyTipo != null) {
          if (legacyEmail != null) {
            await sharedPreferences.setString(_userEmailKey, legacyEmail);
            email = legacyEmail;
          }
          if (legacyId != null) {
            await sharedPreferences.setInt(_userIdKey, legacyId);
            id = legacyId;
          }
          if (legacyTipo != null) {
            await sharedPreferences.setString(_userTypeKey, legacyTipo);
            tipoUsuario = legacyTipo;
          }

          await sharedPreferences.remove(_legacyUserEmailKey);
          await sharedPreferences.remove(_legacyUserIdKey);
          await sharedPreferences.remove(_legacyUserTypeKey);
        }
      }

      if (email != null || id != null) {
        return {
          'user': {
            if (id != null) 'id': id,
            if (email != null) 'email': email,
            if (tipoUsuario != null) 'tipo_usuario': tipoUsuario,
          },
          'login_at': DateTime.now().toIso8601String(),
          'migrated': true,
        };
      }

      return null;
    } catch (e) {
      throw CacheException('Error al obtener sesiÃ³n: ${e.toString()}');
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await Future.wait([
        sharedPreferences.remove(_sessionKey),
        sharedPreferences.remove(_userEmailKey),
        sharedPreferences.remove(_userIdKey),
        sharedPreferences.remove(_userTypeKey),
        // TambiÃ©n eliminar claves legacy
        sharedPreferences.remove(_legacySessionKey),
        sharedPreferences.remove(_legacyUserEmailKey),
        sharedPreferences.remove(_legacyUserIdKey),
        sharedPreferences.remove(_legacyUserTypeKey),
      ]);
    } catch (e) {
      throw CacheException('Error al limpiar sesiÃ³n: ${e.toString()}');
    }
  }
}

import 'package:dartz/dartz.dart';
import '../../../user/domain/entities/user.dart';
import '../../../../core/error/failures.dart';

abstract class AdminUserRepository {
  /// Obtiene la lista de usuarios con filtros
  Future<Either<Failure, Map<String, dynamic>>> getUsers({
    required int adminId,
    int page = 1,
    int perPage = 20,
    String? search,
    String? tipoUsuario,
    bool? esActivo,
  });

  /// Actualiza un usuario existente
  Future<Either<Failure, bool>> updateUser({
    required int adminId,
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? tipoUsuario,
    bool? esActivo,
    bool? esVerificado,
  });

  /// Elimina (o desactiva) un usuario
  Future<Either<Failure, bool>> deleteUser({
    required int adminId,
    required int userId,
  });
}

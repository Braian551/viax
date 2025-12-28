import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/admin_user_repository.dart';

class ManageUserUseCase {
  final AdminUserRepository repository;

  ManageUserUseCase(this.repository);

  Future<Either<Failure, bool>> updateUser({
    required int adminId,
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? tipoUsuario,
    bool? esActivo,
    bool? esVerificado,
    int? empresaId,
  }) {
    return repository.updateUser(
      adminId: adminId,
      userId: userId,
      nombre: nombre,
      apellido: apellido,
      telefono: telefono,
      tipoUsuario: tipoUsuario,
      esActivo: esActivo,
      esVerificado: esVerificado,
      empresaId: empresaId,
    );
  }

  Future<Either<Failure, bool>> deleteUser({
    required int adminId,
    required int userId,
  }) {
    return repository.deleteUser(
      adminId: adminId,
      userId: userId,
    );
  }
}

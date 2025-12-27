import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/admin_user_repository.dart';

class GetUsersUseCase {
  final AdminUserRepository repository;

  GetUsersUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call({
    required int adminId,
    int page = 1,
    int perPage = 20,
    String? search,
    String? tipoUsuario,
    bool? esActivo,
  }) {
    return repository.getUsers(
      adminId: adminId,
      page: page,
      perPage: perPage,
      search: search,
      tipoUsuario: tipoUsuario,
      esActivo: esActivo,
    );
  }
}

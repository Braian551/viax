import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/repositories/admin_user_repository.dart';
import '../datasources/admin_remote_datasource.dart';

class AdminUserRepositoryImpl implements AdminUserRepository {
  final AdminRemoteDataSource remoteDataSource;

  AdminUserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUsers({
    required int adminId,
    int page = 1,
    int perPage = 20,
    String? search,
    String? tipoUsuario,
    bool? esActivo,
  }) async {
    try {
      final result = await remoteDataSource.getUsers(
        adminId: adminId,
        page: page,
        perPage: perPage,
        search: search,
        tipoUsuario: tipoUsuario,
        esActivo: esActivo,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updateUser({
    required int adminId,
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? tipoUsuario,
    bool? esActivo,
    bool? esVerificado,
  }) async {
    try {
      final result = await remoteDataSource.updateUser(
        adminId: adminId,
        userId: userId,
        nombre: nombre,
        apellido: apellido,
        telefono: telefono,
        tipoUsuario: tipoUsuario,
        esActivo: esActivo,
        esVerificado: esVerificado,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteUser({
    required int adminId,
    required int userId,
  }) async {
    try {
      final result = await remoteDataSource.deleteUser(
        adminId: adminId,
        userId: userId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

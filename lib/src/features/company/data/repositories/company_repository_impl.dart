/// Company Repository Implementation
/// Implements the domain repository contract using remote data source

import 'package:dartz/dartz.dart';
import 'package:viax/src/core/error/failures.dart';
import 'package:viax/src/core/error/exceptions.dart';
import '../../domain/repositories/company_repository.dart';
import '../datasources/company_remote_datasource.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  final CompanyRemoteDataSource remoteDataSource;

  CompanyRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getDrivers(dynamic empresaId) async {
    try {
      final drivers = await remoteDataSource.getDrivers(empresaId);
      return Right(drivers);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPricing(dynamic empresaId) async {
    try {
      final pricing = await remoteDataSource.getPricing(empresaId);
      return Right(pricing);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> updatePricing(dynamic empresaId, List<Map<String, dynamic>> precios) async {
    try {
      final success = await remoteDataSource.updatePricing(empresaId, precios);
      return Right(success);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCompanyDetails(dynamic empresaId) async {
    try {
      final details = await remoteDataSource.getCompanyDetails(empresaId);
      return Right(details);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: $e'));
    }
  }
}

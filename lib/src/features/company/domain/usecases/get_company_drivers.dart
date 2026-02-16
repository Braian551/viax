/// Get Company Drivers Use Case
library;

import 'package:dartz/dartz.dart';
import 'package:viax/src/core/error/failures.dart';
import '../repositories/company_repository.dart';

class GetCompanyDrivers {
  final CompanyRepository repository;

  GetCompanyDrivers(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(dynamic empresaId) {
    return repository.getDrivers(empresaId);
  }
}

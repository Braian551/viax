/// Update Company Pricing Use Case
library;

import 'package:dartz/dartz.dart';
import 'package:viax/src/core/error/failures.dart';
import '../repositories/company_repository.dart';

class UpdateCompanyPricing {
  final CompanyRepository repository;

  UpdateCompanyPricing(this.repository);

  Future<Either<Failure, bool>> call(dynamic empresaId, List<Map<String, dynamic>> precios) {
    return repository.updatePricing(empresaId, precios);
  }
}

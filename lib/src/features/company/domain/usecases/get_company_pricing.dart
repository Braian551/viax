/// Get Company Pricing Use Case
library;

import 'package:dartz/dartz.dart';
import 'package:viax/src/core/error/failures.dart';
import '../repositories/company_repository.dart';

class GetCompanyPricing {
  final CompanyRepository repository;

  GetCompanyPricing(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(dynamic empresaId) {
    return repository.getPricing(empresaId);
  }
}

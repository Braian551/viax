/// Company Repository Contract
/// Defines the interface for company data operations

import 'package:dartz/dartz.dart';
import 'package:viax/src/core/error/failures.dart';

abstract class CompanyRepository {
  /// Get all drivers associated with a company
  Future<Either<Failure, List<Map<String, dynamic>>>> getDrivers(dynamic empresaId);
  
  /// Get pricing configuration for a company
  Future<Either<Failure, List<Map<String, dynamic>>>> getPricing(dynamic empresaId);
  
  /// Update pricing configuration for a company
  Future<Either<Failure, bool>> updatePricing(dynamic empresaId, List<Map<String, dynamic>> precios);

  /// Get company details
  Future<Either<Failure, Map<String, dynamic>>> getCompanyDetails(dynamic id);
}

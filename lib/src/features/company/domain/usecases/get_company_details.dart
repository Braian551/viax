import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/company_repository.dart';

class GetCompanyDetails {
  final CompanyRepository repository;

  GetCompanyDetails(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(dynamic id) async {
    return await repository.getCompanyDetails(id);
  }
}

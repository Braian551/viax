import '../../domain/entities/empresa_transporte.dart';
import '../../domain/repositories/empresa_repository.dart';
import '../datasources/empresa_remote_datasource.dart';

/// Implementación del repositorio de empresas
class EmpresaRepositoryImpl implements EmpresaRepository {
  final EmpresaRemoteDataSource remoteDataSource;

  EmpresaRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<EmpresaTransporte>> getEmpresas({
    String? estado,
    String? municipio,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    return await remoteDataSource.getEmpresas(
      estado: estado,
      municipio: municipio,
      search: search,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<EmpresaTransporte> getEmpresaById(int id) async {
    return await remoteDataSource.getEmpresaById(id);
  }

  @override
  Future<int> createEmpresa(Map<String, dynamic> empresaData, int adminId) async {
    return await remoteDataSource.createEmpresa(empresaData, adminId);
  }

  @override
  Future<void> updateEmpresa(int id, Map<String, dynamic> empresaData, int adminId) async {
    await remoteDataSource.updateEmpresa(id, empresaData, adminId);
  }

  @override
  Future<void> deleteEmpresa(int id, int adminId) async {
    await remoteDataSource.deleteEmpresa(id, adminId);
  }

  @override
  Future<void> toggleEmpresaStatus(int id, String estado, int adminId) async {
    await remoteDataSource.toggleEmpresaStatus(id, estado, adminId);
  }

  @override
  Future<void> approveEmpresa(int id, int adminId) async {
    await remoteDataSource.approveEmpresa(id, adminId);
  }

  @override
  Future<void> rejectEmpresa(int id, int adminId, String motivo) async {
    await remoteDataSource.rejectEmpresa(id, adminId, motivo);
  }

  @override
  Future<EmpresaStats> getEmpresaStats() async {
    return await remoteDataSource.getEmpresaStats();
  }
}

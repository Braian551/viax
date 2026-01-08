import '../../domain/entities/empresa_transporte.dart';

/// Repositorio abstracto para empresas de transporte
abstract class EmpresaRepository {
  /// Obtiene lista de empresas con filtros opcionales
  Future<List<EmpresaTransporte>> getEmpresas({
    String? estado,
    String? municipio,
    String? search,
    int page = 1,
    int limit = 50,
  });

  /// Obtiene una empresa por su ID
  Future<EmpresaTransporte> getEmpresaById(int id);

  /// Crea una nueva empresa y devuelve su ID
  Future<int> createEmpresa(Map<String, dynamic> empresaData, int adminId);

  /// Actualiza una empresa existente
  Future<void> updateEmpresa(int id, Map<String, dynamic> empresaData, int adminId);

  /// Elimina una empresa (soft delete)
  Future<void> deleteEmpresa(int id, int adminId);

  /// Cambia el estado de una empresa
  Future<void> toggleEmpresaStatus(int id, String estado, int adminId);

  /// Aprueba una empresa pendiente
  Future<void> approveEmpresa(int id, int adminId);

  /// Rechaza una empresa pendiente
  Future<void> rejectEmpresa(int id, int adminId, String motivo);

  /// Obtiene estadísticas de empresas
  Future<EmpresaStats> getEmpresaStats();
}

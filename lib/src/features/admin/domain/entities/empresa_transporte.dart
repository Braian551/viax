/// Entidad de Dominio: EmpresaTransporte
/// 
/// Representa una empresa de transporte registrada en el sistema.
/// Las empresas pueden tener conductores asociados y los clientes
/// pueden seleccionar una empresa preferida.
class EmpresaTransporte {
  final int id;
  final String nombre;
  final String? nit;
  final String? razonSocial;
  final String? email;
  final String? telefono;
  final String? telefonoSecundario;
  final String? direccion;
  final String? municipio;
  final String? departamento;
  final String? representanteNombre;
  final String? representanteTelefono;
  final String? representanteEmail;
  final List<String> tiposVehiculo;
  final String? logoUrl;
  final String? descripcion;
  final EmpresaEstado estado;
  final bool verificada;
  final DateTime? fechaVerificacion;
  final int? verificadoPor;
  final int totalConductores;
  final int totalViajesCompletados;
  final double calificacionPromedio;
  final double comisionAdminPorcentaje;
  final DateTime creadoEn;
  final DateTime? actualizadoEn;
  final int? creadoPor;
  final String? notasAdmin;

  const EmpresaTransporte({
    required this.id,
    required this.nombre,
    this.nit,
    this.razonSocial,
    this.email,
    this.telefono,
    this.telefonoSecundario,
    this.direccion,
    this.municipio,
    this.departamento,
    this.representanteNombre,
    this.representanteTelefono,
    this.representanteEmail,
    this.tiposVehiculo = const [],
    this.logoUrl,
    this.descripcion,
    this.estado = EmpresaEstado.activo,
    this.verificada = false,
    this.fechaVerificacion,
    this.verificadoPor,
    this.totalConductores = 0,
    this.totalViajesCompletados = 0,
    this.calificacionPromedio = 0.0,
    this.comisionAdminPorcentaje = 0.0,
    required this.creadoEn,
    this.actualizadoEn,
    this.creadoPor,
    this.notasAdmin,
  });

  /// Crea una copia de la empresa con los valores modificados
  EmpresaTransporte copyWith({
    int? id,
    String? nombre,
    String? nit,
    String? razonSocial,
    String? email,
    String? telefono,
    String? telefonoSecundario,
    String? direccion,
    String? municipio,
    String? departamento,
    String? representanteNombre,
    String? representanteTelefono,
    String? representanteEmail,
    List<String>? tiposVehiculo,
    String? logoUrl,
    String? descripcion,
    EmpresaEstado? estado,
    bool? verificada,
    DateTime? fechaVerificacion,
    int? verificadoPor,
    int? totalConductores,
    int? totalViajesCompletados,
    double? calificacionPromedio,
    double? comisionAdminPorcentaje,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    int? creadoPor,
    String? notasAdmin,
  }) {
    return EmpresaTransporte(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nit: nit ?? this.nit,
      razonSocial: razonSocial ?? this.razonSocial,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      telefonoSecundario: telefonoSecundario ?? this.telefonoSecundario,
      direccion: direccion ?? this.direccion,
      municipio: municipio ?? this.municipio,
      departamento: departamento ?? this.departamento,
      representanteNombre: representanteNombre ?? this.representanteNombre,
      representanteTelefono: representanteTelefono ?? this.representanteTelefono,
      representanteEmail: representanteEmail ?? this.representanteEmail,
      tiposVehiculo: tiposVehiculo ?? this.tiposVehiculo,
      logoUrl: logoUrl ?? this.logoUrl,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      verificada: verificada ?? this.verificada,
      fechaVerificacion: fechaVerificacion ?? this.fechaVerificacion,
      verificadoPor: verificadoPor ?? this.verificadoPor,
      totalConductores: totalConductores ?? this.totalConductores,
      totalViajesCompletados: totalViajesCompletados ?? this.totalViajesCompletados,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      comisionAdminPorcentaje: comisionAdminPorcentaje ?? this.comisionAdminPorcentaje,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      creadoPor: creadoPor ?? this.creadoPor,
      notasAdmin: notasAdmin ?? this.notasAdmin,
    );
  }
}

/// Estados posibles de una empresa
enum EmpresaEstado {
  activo('activo', 'Activo'),
  inactivo('inactivo', 'Inactivo'),
  suspendido('suspendido', 'Suspendido'),
  pendiente('pendiente', 'Pendiente'),
  eliminado('eliminado', 'Eliminado');

  final String value;
  final String displayName;
  
  const EmpresaEstado(this.value, this.displayName);

  static EmpresaEstado fromString(String? value) {
    return EmpresaEstado.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EmpresaEstado.activo,
    );
  }
}

/// Estadísticas de empresas
class EmpresaStats {
  final int totalEmpresas;
  final int activas;
  final int inactivas;
  final int pendientes;
  final int verificadas;
  final int totalConductores;
  final int totalViajes;

  const EmpresaStats({
    required this.totalEmpresas,
    required this.activas,
    required this.inactivas,
    required this.pendientes,
    required this.verificadas,
    required this.totalConductores,
    required this.totalViajes,
  });
}

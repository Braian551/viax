import 'dart:io';
import '../../domain/entities/empresa_transporte.dart';

/// Modelo de Datos para EmpresaTransporte
/// 
/// Extiende la entidad de dominio y añade métodos de serialización
/// para comunicación con el backend.
class EmpresaTransporteModel extends EmpresaTransporte {
  const EmpresaTransporteModel({
    required super.id,
    required super.nombre,
    super.nit,
    super.razonSocial,
    super.email,
    super.telefono,
    super.telefonoSecundario,
    super.direccion,
    super.municipio,
    super.departamento,
    super.representanteNombre,
    super.representanteTelefono,
    super.representanteEmail,
    super.tiposVehiculo,
    super.logoUrl,
    super.descripcion,
    super.estado,
    super.verificada,
    super.fechaVerificacion,
    super.verificadoPor,
    super.totalConductores,
    super.totalViajesCompletados,
    super.calificacionPromedio,
    required super.creadoEn,
    super.actualizadoEn,
    super.creadoPor,
    super.notasAdmin,
  });

  /// Crea una instancia desde un mapa JSON
  factory EmpresaTransporteModel.fromJson(Map<String, dynamic> json) {
    return EmpresaTransporteModel(
      id: _parseInt(json['id']),
      nombre: json['nombre']?.toString() ?? '',
      nit: json['nit']?.toString(),
      razonSocial: json['razon_social']?.toString(),
      email: json['email']?.toString(),
      telefono: json['telefono']?.toString(),
      telefonoSecundario: json['telefono_secundario']?.toString(),
      direccion: json['direccion']?.toString(),
      municipio: json['municipio']?.toString(),
      departamento: json['departamento']?.toString(),
      representanteNombre: json['representante_nombre']?.toString(),
      representanteTelefono: json['representante_telefono']?.toString(),
      representanteEmail: json['representante_email']?.toString(),
      tiposVehiculo: _parseStringList(json['tipos_vehiculo']),
      logoUrl: json['logo_url']?.toString(),
      descripcion: json['descripcion']?.toString(),
      estado: EmpresaEstado.fromString(json['estado']?.toString()),
      verificada: _parseBool(json['verificada']),
      fechaVerificacion: _parseDateTime(json['fecha_verificacion']),
      verificadoPor: _parseNullableInt(json['verificado_por']),
      totalConductores: _parseInt(json['total_conductores']),
      totalViajesCompletados: _parseInt(json['total_viajes_completados']),
      calificacionPromedio: _parseDouble(json['calificacion_promedio']),
      creadoEn: _parseDateTime(json['creado_en']) ?? DateTime.now(),
      actualizadoEn: _parseDateTime(json['actualizado_en']),
      creadoPor: _parseNullableInt(json['creado_por']),
      notasAdmin: json['notas_admin']?.toString(),
    );
  }

  /// Convierte la instancia a un mapa JSON para enviar al servidor
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'nombre': nombre,
      if (nit != null) 'nit': nit,
      if (razonSocial != null) 'razon_social': razonSocial,
      if (email != null) 'email': email,
      if (telefono != null) 'telefono': telefono,
      if (telefonoSecundario != null) 'telefono_secundario': telefonoSecundario,
      if (direccion != null) 'direccion': direccion,
      if (municipio != null) 'municipio': municipio,
      if (departamento != null) 'departamento': departamento,
      if (representanteNombre != null) 'representante_nombre': representanteNombre,
      if (representanteTelefono != null) 'representante_telefono': representanteTelefono,
      if (representanteEmail != null) 'representante_email': representanteEmail,
      if (tiposVehiculo.isNotEmpty) 'tipos_vehiculo': tiposVehiculo,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (descripcion != null) 'descripcion': descripcion,
      'estado': estado.value,
      if (notasAdmin != null) 'notas_admin': notasAdmin,
    };
  }

  /// Helpers para parsing seguro
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    if (value is int) return value == 1;
    return false;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}

/// Modelo para estadísticas de empresas
class EmpresaStatsModel extends EmpresaStats {
  const EmpresaStatsModel({
    required super.totalEmpresas,
    required super.activas,
    required super.inactivas,
    required super.pendientes,
    required super.verificadas,
    required super.totalConductores,
    required super.totalViajes,
  });

  factory EmpresaStatsModel.fromJson(Map<String, dynamic> json) {
    return EmpresaStatsModel(
      totalEmpresas: _parseInt(json['total_empresas']),
      activas: _parseInt(json['activas']),
      inactivas: _parseInt(json['inactivas']),
      pendientes: _parseInt(json['pendientes']),
      verificadas: _parseInt(json['verificadas']),
      totalConductores: _parseInt(json['total_conductores']),
      totalViajes: _parseInt(json['total_viajes']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

/// Modelo para crear/actualizar empresa
class EmpresaFormData {
  String nombre;
  String? nit;
  String? razonSocial;
  String? email;
  String? telefono;
  String? telefonoSecundario;
  String? direccion;
  String? municipio;
  String? departamento;
  String? representanteNombre;
  String? representanteTelefono;
  String? representanteEmail;
  List<String> tiposVehiculo;
  String? logoUrl;
  File? logoFile;
  String? descripcion;
  String estado;
  String? notasAdmin;
  String? password;

  EmpresaFormData({
    this.nombre = '',
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
    this.logoFile,
    this.descripcion,
    this.estado = 'activo',
    this.notasAdmin,
    this.password,
  });

  /// Crea un formulario a partir de una empresa existente
  factory EmpresaFormData.fromEmpresa(EmpresaTransporte empresa) {
    return EmpresaFormData(
      nombre: empresa.nombre,
      nit: empresa.nit,
      razonSocial: empresa.razonSocial,
      email: empresa.email,
      telefono: empresa.telefono,
      telefonoSecundario: empresa.telefonoSecundario,
      direccion: empresa.direccion,
      municipio: empresa.municipio,
      departamento: empresa.departamento,
      representanteNombre: empresa.representanteNombre,
      representanteTelefono: empresa.representanteTelefono,
      representanteEmail: empresa.representanteEmail,
      tiposVehiculo: List.from(empresa.tiposVehiculo),
      logoUrl: empresa.logoUrl,
      descripcion: empresa.descripcion,
      estado: empresa.estado.value,
      notasAdmin: empresa.notasAdmin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      if (nit != null && nit!.isNotEmpty) 'nit': nit,
      if (razonSocial != null && razonSocial!.isNotEmpty) 'razon_social': razonSocial,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
      if (telefonoSecundario != null && telefonoSecundario!.isNotEmpty) 'telefono_secundario': telefonoSecundario,
      if (direccion != null && direccion!.isNotEmpty) 'direccion': direccion,
      if (municipio != null && municipio!.isNotEmpty) 'municipio': municipio,
      if (departamento != null && departamento!.isNotEmpty) 'departamento': departamento,
      if (representanteNombre != null && representanteNombre!.isNotEmpty) 'representante_nombre': representanteNombre,
      if (representanteTelefono != null && representanteTelefono!.isNotEmpty) 'representante_telefono': representanteTelefono,
      if (representanteEmail != null && representanteEmail!.isNotEmpty) 'representante_email': representanteEmail,
      if (tiposVehiculo.isNotEmpty) 'tipos_vehiculo': tiposVehiculo,
      if (logoUrl != null && logoUrl!.isNotEmpty) 'logo_url': logoUrl,
      if (descripcion != null && descripcion!.isNotEmpty) 'descripcion': descripcion,
      'estado': estado,
      if (notasAdmin != null && notasAdmin!.isNotEmpty) 'notas_admin': notasAdmin,
      if (password != null && password!.isNotEmpty) 'password': password,
    };
  }

  bool get isValid => nombre.trim().isNotEmpty;
}

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/conductor_profile_model.dart';
import '../models/driver_license_model.dart';
import '../models/vehicle_model.dart';
import '../services/conductor_profile_service.dart';
import '../services/document_upload_service.dart';
import '../services/conductor_service.dart';

class ConductorProfileProvider with ChangeNotifier {
  ConductorProfileModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  double _uploadProgress = 0.0;
  Map<String, dynamic>? _companyInfo;

  ConductorProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get uploadProgress => _uploadProgress;
  Map<String, dynamic>? get companyInfo => _companyInfo;

  /// Cargar perfil del conductor
  Future<void> loadProfile(int conductorId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await ConductorProfileService.getProfile(conductorId);
      
      // Fetch statistics and basic info for extended profile data
      final stats = await ConductorService.getEstadisticas(conductorId);
      final info = await ConductorService.getConductorInfo(conductorId);

      debugPrint('📊 [ConductorProfile] Stats received: $stats');
      debugPrint('📋 [ConductorProfile] Info received: ${info?['conductor']}');

      if (profile != null) {
        // Merge stats and info into the profile model
        final conductorData = info?['conductor'] as Map<String, dynamic>?;
        
        // Get trips from stats (viajes_totales), fallback to conductor info
        int trips = int.tryParse(stats['viajes_totales']?.toString() ?? '0') ?? 0;
        if (trips == 0 && conductorData != null) {
          trips = int.tryParse(conductorData['total_viajes']?.toString() ?? '0') ?? 0;
        }

        // Get fecha_registro from stats first, fallback to conductorData
        DateTime? fechaRegistro;
        if (stats['fecha_registro'] != null) {
          fechaRegistro = DateTime.tryParse(stats['fecha_registro'].toString());
        }
        if (fechaRegistro == null && conductorData != null && conductorData['fecha_registro'] != null) {
          fechaRegistro = DateTime.tryParse(conductorData['fecha_registro'].toString());
        }

        // Get calificación from stats, fallback to conductorData
        double calificacion = double.tryParse(stats['calificacion_promedio']?.toString() ?? '5.0') ?? 5.0;
        if (calificacion == 0 && conductorData != null) {
          calificacion = double.tryParse(conductorData['calificacion_promedio']?.toString() ?? '5.0') ?? 5.0;
        }
        
        int totalCalificaciones = int.tryParse(stats['total_calificaciones']?.toString() ?? '0') ?? 0;
        if (totalCalificaciones == 0 && conductorData != null) {
          totalCalificaciones = int.tryParse(conductorData['total_calificaciones']?.toString() ?? '0') ?? 0;
        }

        debugPrint('📊 [ConductorProfile] Trips: $trips, FechaRegistro: $fechaRegistro, Rating: $calificacion');

        _profile = profile.copyWith(
          viajes: trips,
          fechaRegistro: fechaRegistro,
          calificacionPromedio: calificacion,
          totalCalificaciones: totalCalificaciones,
        );
        _errorMessage = null;
      } else {
        _errorMessage = 'No se pudo cargar el perfil';
        // Inicializar perfil vacío con datos básicos si es posible
        final conductorData = info?['conductor'] as Map<String, dynamic>?;
        
        int trips = int.tryParse(stats['viajes_totales']?.toString() ?? '0') ?? 0;
        if (trips == 0 && conductorData != null) {
          trips = int.tryParse(conductorData['total_viajes']?.toString() ?? '0') ?? 0;
        }

        // Get fecha_registro from stats first, fallback to conductorData
        DateTime? fechaRegistro;
        if (stats['fecha_registro'] != null) {
          fechaRegistro = DateTime.tryParse(stats['fecha_registro'].toString());
        }
        if (fechaRegistro == null && conductorData != null && conductorData['fecha_registro'] != null) {
          fechaRegistro = DateTime.tryParse(conductorData['fecha_registro'].toString());
        }

        // Get calificación from stats, fallback to conductorData
        double calificacion = double.tryParse(stats['calificacion_promedio']?.toString() ?? '5.0') ?? 5.0;
        if (calificacion == 0 && conductorData != null) {
          calificacion = double.tryParse(conductorData['calificacion_promedio']?.toString() ?? '5.0') ?? 5.0;
        }
        
        int totalCalificaciones = int.tryParse(stats['total_calificaciones']?.toString() ?? '0') ?? 0;
        if (totalCalificaciones == 0 && conductorData != null) {
          totalCalificaciones = int.tryParse(conductorData['total_calificaciones']?.toString() ?? '0') ?? 0;
        }

         _profile = ConductorProfileModel(
          viajes: trips,
          fechaRegistro: fechaRegistro,
          calificacionPromedio: calificacion,
          totalCalificaciones: totalCalificaciones,
        );
      }
    } catch (e) {
      _errorMessage = 'Error al cargar perfil: $e';
      print('Error en loadProfile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar información de la empresa
  Future<void> loadCompanyInfo(int empresaId) async {
    // No set loading to true to avoid full screen loader if this is secondary
    try {
      final company = await ConductorProfileService.getCompanyDetails(empresaId);
      if (company != null) {
        _companyInfo = company;
        notifyListeners();
      }
    } catch (e) {
      print('Error cargando info empresa: $e');
    }
  }

  /// Actualizar licencia de conducciÃ³n
  Future<bool> updateLicense({
    required int conductorId,
    required DriverLicenseModel license,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ConductorProfileService.updateLicense(
        conductorId: conductorId,
        license: license,
      );

      if (response['success'] == true) {
        // Actualizar perfil local
        _profile = _profile?.copyWith(licencia: license) ??
            ConductorProfileModel(licencia: license);
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Error al actualizar licencia';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar licencia: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualizar vehÃ­culo
  Future<bool> updateVehicle({
    required int conductorId,
    required VehicleModel vehicle,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ConductorProfileService.updateVehicle(
        conductorId: conductorId,
        vehicle: vehicle,
      );

      if (response['success'] == true) {
        // Actualizar perfil local
        _profile = _profile?.copyWith(vehiculo: vehicle) ??
            ConductorProfileModel(vehiculo: vehicle);
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Error al actualizar vehÃ­culo';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar vehÃ­culo: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Subir documento
  Future<String?> uploadDocument({
    required int conductorId,
    required String documentType,
    required File imageFile,
  }) async {
    _uploadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      _uploadProgress = 0.5;
      notifyListeners();

      final response = await ConductorProfileService.uploadDocument(
        conductorId: conductorId,
        documentType: documentType,
        imageFile: imageFile,
      );

      _uploadProgress = 1.0;
      notifyListeners();

      if (response['success'] == true) {
        _errorMessage = null;
        // Recargar perfil para obtener las URLs actualizadas
        await loadProfile(conductorId);
        return response['file_url'];
      } else {
        _errorMessage = response['message'] ?? 'Error al subir documento';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error al subir documento: $e';
      _uploadProgress = 0.0;
      notifyListeners();
      return null;
    }
  }

  /// Actualizar perfil completo con datos JSON
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ConductorProfileService.updateProfile(data);

      if (response['success'] == true) {
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Error al actualizar perfil';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar perfil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Enviar perfil para verificaciÃ³n
  Future<bool> submitForVerification(int conductorId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ConductorProfileService.submitForVerification(
        conductorId,
      );

      if (response['success'] == true) {
        // Actualizar estado de verificaciÃ³n
        _profile = _profile?.copyWith(
          estadoVerificacion: VerificationStatus.enRevision,
        );
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Error al enviar verificaciÃ³n';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al enviar verificaciÃ³n: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener estado de verificaciÃ³n
  Future<void> refreshVerificationStatus(int conductorId) async {
    try {
      final response = await ConductorProfileService.getVerificationStatus(
        conductorId,
      );

      if (response['success'] == true) {
        final status = VerificationStatus.fromString(
          response['estado_verificacion']?.toString() ?? 'pendiente',
        );
        
        _profile = _profile?.copyWith(
          estadoVerificacion: status,
          aprobado: response['aprobado'] == true || response['aprobado'] == 1,
          documentosPendientes: response['documentos_pendientes'] != null
              ? List<String>.from(response['documentos_pendientes'])
              : [],
          documentosRechazados: response['documentos_rechazados'] != null
              ? List<String>.from(response['documentos_rechazados'])
              : [],
          motivoRechazo: response['motivo_rechazo']?.toString(),
        );
        
        notifyListeners();
      }
    } catch (e) {
      print('Error refrescando estado de verificaciÃ³n: $e');
    }
  }

  /// Subir mÃºltiples documentos del vehÃ­culo
  Future<Map<String, String?>> uploadVehicleDocuments({
    required int conductorId,
    String? soatFotoPath,
    String? tecnomecanicaFotoPath,
    String? tarjetaPropiedadFotoPath,
  }) async {
    final results = <String, String?>{};
    _errorMessage = null;

    try {
      final documents = <String, String>{};
      
      if (soatFotoPath != null) {
        documents['soat'] = soatFotoPath;
      }
      if (tecnomecanicaFotoPath != null) {
        documents['tecnomecanica'] = tecnomecanicaFotoPath;
      }
      if (tarjetaPropiedadFotoPath != null) {
        documents['tarjeta_propiedad'] = tarjetaPropiedadFotoPath;
      }

      if (documents.isEmpty) {
        return results;
      }

      _isLoading = true;
      notifyListeners();

      results.addAll(
        await DocumentUploadService.uploadMultipleDocuments(
          conductorId: conductorId,
          documents: documents,
        ),
      );

      _isLoading = false;
      notifyListeners();

      // Recargar perfil si algÃºn upload fue exitoso
      final hasSuccessfulUpload = results.values.any((url) => url != null);
      if (hasSuccessfulUpload) {
        await loadProfile(conductorId);
      }

      return results;
    } catch (e) {
      _errorMessage = 'Error al subir documentos: $e';
      _isLoading = false;
      notifyListeners();
      return results;
    }
  }

  /// Subir foto de licencia
  Future<String?> uploadLicensePhoto({
    required int conductorId,
    required String licenciaFotoPath,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final url = await DocumentUploadService.uploadDocument(
        conductorId: conductorId,
        tipoDocumento: 'licencia',
        imagePath: licenciaFotoPath,
      );

      _isLoading = false;
      notifyListeners();

      // Recargar perfil si el upload fue exitoso
      if (url != null) {
        await loadProfile(conductorId);
      }

      return url;
    } catch (e) {
      _errorMessage = 'Error al subir foto de licencia: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Limpiar mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpiar perfil
  void clear() {
    _profile = null;
    _isLoading = false;
    _errorMessage = null;
    _uploadProgress = 0.0;
    notifyListeners();
  }
}

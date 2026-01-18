import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/app_config.dart';

/// Servicio para subir documentos del conductor
/// Soporta imágenes (jpg, jpeg, png, webp) hasta 5MB y PDFs hasta 10MB
class DocumentUploadService {
  /// Sube un documento/foto al servidor
  /// 
  /// [conductorId] - ID del conductor
  /// [tipoDocumento] - Tipo: 'licencia', 'soat', 'tecnomecanica', 'tarjeta_propiedad', 'seguro'
  /// [imagePath] - Ruta local del archivo a subir (imagen o PDF)
  /// 
  /// Retorna la URL relativa del documento subido o null si hay error
  static Future<String?> uploadDocument({
    required int conductorId,
    required String tipoDocumento,
    required String imagePath,
  }) async {
    debugPrint('Iniciando subida de documento: $tipoDocumento para conductor: $conductorId');
    debugPrint('Ruta del archivo: $imagePath');

    try {
      final file = File(imagePath);

      if (!await file.exists()) {
        debugPrint('Error: El archivo no existe: $imagePath');
        return null;
      }

      // Determinar si es PDF o imagen
      final extension = imagePath.toLowerCase().split('.').last;
      final isPdf = extension == 'pdf';
      
      // Validar tamaño (max 10MB para PDFs, 5MB para imágenes)
      final maxSize = isPdf ? 10 * 1024 * 1024 : 5 * 1024 * 1024;
      final fileSize = await file.length();
      debugPrint('Tamaño del archivo: ${fileSize} bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      debugPrint('Tipo de archivo: ${isPdf ? 'PDF' : 'Imagen'}');

      if (fileSize > maxSize) {
        final maxMB = maxSize / 1024 / 1024;
        debugPrint('Error: El archivo excede ${maxMB}MB');
        return null;
      }

      final uri = Uri.parse('${AppConfig.conductorServiceUrl}/upload_documents.php');
      debugPrint('URL del endpoint: $uri');

      final request = http.MultipartRequest('POST', uri);

      // Agregar campos
      request.fields['conductor_id'] = conductorId.toString();
      request.fields['tipo_documento'] = tipoDocumento;
      debugPrint('Campos enviados: conductor_id=$conductorId, tipo_documento=$tipoDocumento');

      // Agregar archivo
      final fileName = imagePath.split(Platform.pathSeparator).last;
      debugPrint('Nombre del archivo: $fileName');

      // Verificar nuevamente que el archivo existe justo antes de subirlo
      if (!await file.exists()) {
        debugPrint('El archivo dejÃ³ de existir antes de subirlo: $imagePath');
        return null;
      }

      final multipartFile = await http.MultipartFile.fromPath(
        'documento',
        imagePath,
        filename: fileName,
      );
      request.files.add(multipartFile);
      debugPrint('Archivo agregado al request correctamente');

      // Enviar request
      debugPrint('Enviando request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final url = data['data']['url'];
          debugPrint('Documento subido exitosamente: $url');
          return url;
        } else {
          debugPrint('Error del servidor: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('Error HTTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error al subir documento: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Sube mÃºltiples documentos en lote
  /// 
  /// Retorna un Map con el tipo de documento y su URL
  static Future<Map<String, String?>> uploadMultipleDocuments({
    required int conductorId,
    Map<String, String>? documents,
  }) async {
    final results = <String, String?>{};

    if (documents == null || documents.isEmpty) {
      return results;
    }

    for (final entry in documents.entries) {
      final tipoDocumento = entry.key;
      final imagePath = entry.value;

      final url = await uploadDocument(
        conductorId: conductorId,
        tipoDocumento: tipoDocumento,
        imagePath: imagePath,
      );

      results[tipoDocumento] = url;
      
      // PequeÃ±a pausa entre uploads para no saturar el servidor
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return results;
  }

  /// Obtiene la URL completa del documento
  /// Obtiene la URL completa del documento
  static String getDocumentUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }

    // Si parece ser un archivo de R2 (profile/, imagenes/, pdfs/), usar el proxy
    if (relativeUrl.startsWith('profile/') || 
        relativeUrl.startsWith('imagenes/') || 
        relativeUrl.startsWith('pdfs/')) {
       // Asegurarse de que no estamos duplicando la query del proxy si ya viene
       if (relativeUrl.contains('r2_proxy.php')) return '${AppConfig.baseUrl}/$relativeUrl';
       
       return '${AppConfig.baseUrl}/r2_proxy.php?key=$relativeUrl';
    }

    return '${AppConfig.baseUrl}/$relativeUrl';
  }

  /// Valida que el tipo de documento sea vÃ¡lido
  static bool isValidDocumentType(String tipo) {
    const validTypes = [
      'licencia',
      'soat',
      'tecnomecanica',
      'tarjeta_propiedad',
    ];
    return validTypes.contains(tipo);
  }
}

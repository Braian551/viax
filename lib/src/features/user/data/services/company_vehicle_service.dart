import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/models/company_vehicle_models.dart';

/// Servicio para obtener empresas y vehículos por municipio
class CompanyVehicleService {
  /// Obtiene las empresas que operan en un municipio, junto con sus
  /// tipos de vehículo disponibles, conductores cercanos y tarifas
  static Future<CompanyVehicleResponse> getCompaniesByMunicipality({
    required double latitud,
    required double longitud,
    required String municipio,
    double distanciaKm = 0,
    int duracionMinutos = 0,
    double radioKm = 10,
    String search = '',
  }) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/user/get_companies_by_municipality.php',
      );

      debugPrint('🚗 CompanyVehicleService: Buscando empresas...');
      debugPrint('[CompanySearch] municipality_detected=$municipio');
      debugPrint('   📍 Lat: $latitud, Lon: $longitud');
      debugPrint('   🏘️ Municipio: $municipio');
      debugPrint(
        '   📏 Distancia: ${distanciaKm}km, Duración: ${duracionMinutos}min',
      );

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitud': latitud,
              'longitud': longitud,
              'municipio': municipio,
              'distancia_km': distanciaKm,
              'duracion_minutos': duracionMinutos,
              'radio_km': radioKm,
              'search': search,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint(
        '📥 Response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = CompanyVehicleResponse.fromJson(data);

        debugPrint('✅ Empresas encontradas: ${result.totalEmpresas}');
        debugPrint('[CompanySearch] companies_found=${result.totalEmpresas}');
        debugPrint('✅ Tipos de vehículo: ${result.totalTiposVehiculo}');
        for (var v in result.vehiculosDisponibles) {
          debugPrint('   🚙 ${v.tipo}: ${v.empresas.length} empresas');
          for (var e in v.empresas) {
            debugPrint(
              '      - ${e.nombre}: \$${e.tarifaTotal} (${e.conductores} conductores)',
            );
          }
        }

        return result;
      } else {
        final data = jsonDecode(response.body);
        debugPrint('❌ Error: ${data['message']}');
        return CompanyVehicleResponse.error(
          data['message'] ??
              'Error al obtener empresas: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error de conexión: $e');
      return CompanyVehicleResponse.error('Error de conexión: $e');
    }
  }

  /// Extrae el municipio de una dirección (formato: "..., Municipio, Antioquia, Colombia")
  /// Maneja varios formatos como:
  /// - "Cañasgordas, Antioquia, Colombia"
  /// - "Calle X, Cañasgordas, Antioquia, Colombia"
  /// - "Cañasgordas - Santafé de Antioquia, 0570..."
  static String? extractMunicipalityFromAddress(String? address) {
    if (address == null || address.isEmpty) return null;

    // Normalizar: quitar códigos postales y números al final
    String cleaned = address.replaceAll(RegExp(r'\d{4,}.*$'), '').trim();
    
    // Si hay guión, puede ser formato "Municipio - Subregión" -> tomar el primero
    if (cleaned.contains(' - ')) {
      final dashParts = cleaned.split(' - ');
      // El municipio suele ser el primero antes del guión
      final firstPart = dashParts.first.trim();
      // Pero si el primer parte tiene coma, procesar normal
      if (!firstPart.contains(',')) {
        debugPrint('🏘️ Municipio extraído (por guión): $firstPart');
        return firstPart;
      }
      cleaned = firstPart;
    }
    
    // Formato típico: "Calle X, Municipio, Antioquia, Colombia"
    final parts = cleaned.split(',').map((e) => e.trim()).toList();

    // Palabras a ignorar
    final ignoreWords = [
      'colombia',
      'antioquia',
      'cundinamarca',
      'valle del cauca',
      'atlántico',
      'santander',
      'bolivar',
      'boyacá',
    ];

    // Buscar el municipio (generalmente el penúltimo antes del país)
    if (parts.length >= 2) {
      // Filtrar partes ignoradas (país, departamento)
      final relevantParts = parts.where((p) {
        final lower = p.toLowerCase();
        return !ignoreWords.any((word) => lower.contains(word)) &&
               p.isNotEmpty &&
               !RegExp(r'^\d+$').hasMatch(p); // Ignorar solo números
      }).toList();

      if (relevantParts.isNotEmpty) {
        // El municipio suele ser el último de los relevantes
        // Pero si hay dirección (calle, carrera, etc), tomar el siguiente
        String candidate = relevantParts.last;
        
        // Si parece una dirección (Calle, Carrera, Cra, Cl, etc), tomar el penúltimo
        if (relevantParts.length > 1) {
          final firstLower = relevantParts.first.toLowerCase();
          if (firstLower.startsWith('calle') || 
              firstLower.startsWith('carrera') ||
              firstLower.startsWith('cra') ||
              firstLower.startsWith('cl ') ||
              firstLower.startsWith('kr ') ||
              firstLower.startsWith('av') ||
              firstLower.startsWith('diagonal') ||
              firstLower.startsWith('transversal') ||
              RegExp(r'^#?\d').hasMatch(firstLower)) {
            // El primero es una dirección, el municipio es el último
            candidate = relevantParts.last;
          }
        }
        
        // Validar que el candidato NO sea una dirección
        final candidateLower = candidate.toLowerCase();
        if (candidateLower.startsWith('calle') || 
            candidateLower.startsWith('carrera') ||
            candidateLower.startsWith('cra') ||
            candidateLower.startsWith('cl ') ||
            candidateLower.startsWith('kr ') ||
            candidateLower.startsWith('av') ||
            candidateLower.startsWith('diagonal') ||
            candidateLower.startsWith('transversal') ||
            candidateLower.startsWith('circular') ||
            RegExp(r'^#?\d').hasMatch(candidateLower)) {
           debugPrint('⚠️ Candidato rechazado por parecer dirección: $candidate');
           return null;
        }
        
        debugPrint('🏘️ Municipio extraído: $candidate (de ${parts.length} partes)');
        return candidate;
      }
    }
    
    // Si solo hay una parte, verificar también
    if (parts.length == 1 && parts.first.isNotEmpty) {
       final candidate = parts.first;
       final candidateLower = candidate.toLowerCase();
       if (candidateLower.startsWith('calle') || 
            candidateLower.startsWith('carrera') ||
            candidateLower.startsWith('cra') ||
            candidateLower.startsWith('cl ') ||
            candidateLower.startsWith('kr ') ||
            candidateLower.startsWith('av') ||
            candidateLower.startsWith('diagonal') ||
            candidateLower.startsWith('transversal') ||
            candidateLower.startsWith('circular') ||
            RegExp(r'^#?\d').hasMatch(candidateLower)) {
           debugPrint('⚠️ Candidato único rechazado por parecer dirección: $candidate');
           return null;
       }
       
      debugPrint('🏘️ Municipio extraído (único): $candidate');
      return candidate;
    }

    // Último fallback: segundo elemento si hay más de uno
    if (parts.length >= 2) {
      // Validar también el fallback
      final candidate = parts[1];
       final candidateLower = candidate.toLowerCase();
       if (candidateLower.startsWith('calle') || 
            candidateLower.startsWith('carrera') ||
            candidateLower.startsWith('cra') ||
            RegExp(r'^#?\d').hasMatch(candidateLower)) {
           return null;
       }
      
      debugPrint('🏘️ Municipio extraído (fallback): $candidate');
      return candidate;
    }

    debugPrint('⚠️ No se pudo extraer municipio de: $address');
    return null;
  }

  /// Obtiene información detallada de una empresa por su ID
  static Future<CompanyDetails?> getCompanyDetails(int empresaId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.baseUrl}/user/get_company_details.php',
      );

      debugPrint('🏢 CompanyVehicleService: Obteniendo detalles empresa $empresaId');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'empresa_id': empresaId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['empresa'] != null) {
          return CompanyDetails.fromJson(data['empresa']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo detalles de empresa: $e');
      return null;
    }
  }

  /// Mapa de coordenadas centrales de municipios soportados
  static final Map<String, LatLng> _municipalityCenters = {
    'Medellín': const LatLng(6.2476, -75.5658),
    'Bello': const LatLng(6.3373, -75.5579),
    'Envigado': const LatLng(6.1673, -75.5833),
    'Itagüí': const LatLng(6.1846, -75.5991),
    'Sabaneta': const LatLng(6.1515, -75.6166),
    'La Estrella': const LatLng(6.1578, -75.6432),
    'Copacabana': const LatLng(6.3467, -75.5089),
    'Girardota': const LatLng(6.3789, -75.4464),
    'Barbosa': const LatLng(6.4386, -75.3314),
    'Caldas': const LatLng(6.0911, -75.6356),
    'Cañasgordas': const LatLng(6.7523, -76.0261),
    'Santa Fe de Antioquia': const LatLng(6.5564, -75.8277),
    'San Jerónimo': const LatLng(6.4422, -75.7289),
    'Sopetrán': const LatLng(6.5028, -75.7444),
  };

  /// Encuentra el municipio soportado más cercano dado unas coordenadas
  /// Retorna el nombre del municipio (ej: 'Medellín')
  /// Si está a más de 30km de cualquier municipio, retorna null
  static String? findNearestMunicipality(double lat, double lng) {
    String? closest;
    double minDistance = double.infinity;

    _municipalityCenters.forEach((name, center) {
      final distance = const Distance().as(
        LengthUnit.Kilometer,
        LatLng(lat, lng),
        center,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closest = name;
      }
    });

    // Evitar forzar municipios demasiado lejanos para no mostrar
    // empresas fuera del radio operativo real del origen.
    const maxMunicipalityFallbackKm = 30.0;
    if (minDistance > maxMunicipalityFallbackKm) {
      debugPrint('📍 Ubicación fuera de rango operativo: ${minDistance.toStringAsFixed(1)}km de $closest');
      return null;
    }

    debugPrint('📍 Municipio más cercano (coord): $closest a ${minDistance.toStringAsFixed(1)}km');
    return closest;
  }
}

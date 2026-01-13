import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  static String? extractMunicipalityFromAddress(String? address) {
    if (address == null || address.isEmpty) return null;

    // Formato típico: "Calle X, Municipio, Antioquia, Colombia"
    final parts = address.split(',').map((e) => e.trim()).toList();

    // Buscar el municipio (generalmente el penúltimo antes del país)
    if (parts.length >= 3) {
      // Ignorar "Colombia" al final
      final relevantParts = parts
          .where(
            (p) =>
                !p.toLowerCase().contains('colombia') &&
                !p.toLowerCase().contains(
                  'antioquia',
                ), // También ignorar departamento
          )
          .toList();

      if (relevantParts.isNotEmpty) {
        // El municipio suele ser el último de los relevantes
        return relevantParts.last;
      }
    }

    // Fallback: segundo elemento
    if (parts.length >= 2) {
      return parts[1];
    }

    return null;
  }
}

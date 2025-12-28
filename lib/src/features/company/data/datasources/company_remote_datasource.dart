/// Company Remote Data Source
/// Handles HTTP requests to company-related backend endpoints

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/core/error/exceptions.dart';

abstract class CompanyRemoteDataSource {
  Future<List<Map<String, dynamic>>> getDrivers(dynamic empresaId);
  Future<List<Map<String, dynamic>>> getPricing(dynamic empresaId);
  Future<bool> updatePricing(dynamic empresaId, List<Map<String, dynamic>> precios);
  Future<Map<String, dynamic>> getCompanyDetails(dynamic empresaId);
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final http.Client client;

  CompanyRemoteDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>> getCompanyDetails(dynamic empresaId) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/admin/empresas.php?action=get&id=$empresaId');
      print('CompanyRemoteDataSource: Calling URL: $url');
      final response = await client.get(url, headers: {'Accept': 'application/json'});
      print('CompanyRemoteDataSource: Response status: ${response.statusCode}');
      print('CompanyRemoteDataSource: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['empresa']);
        }
        throw ServerException(data['message'] ?? 'Error al obtener detalles de la empresa');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDrivers(dynamic empresaId) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/company/drivers.php?empresa_id=$empresaId');
      final response = await client.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']['conductores'] ?? []);
        }
        throw ServerException(data['message'] ?? 'Error al obtener conductores');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPricing(dynamic empresaId) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/company/pricing.php?empresa_id=$empresaId');
      final response = await client.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
        throw ServerException(data['message'] ?? 'Error al obtener tarifas');
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }

  @override
  Future<bool> updatePricing(dynamic empresaId, List<Map<String, dynamic>> precios) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/company/pricing.php');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'empresa_id': empresaId, 'precios': precios}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      throw ServerException('Error del servidor: ${response.statusCode}');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Error de conexión: $e');
    }
  }
}

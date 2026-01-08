import 'dart:convert';
import 'package:http/http.dart' as http;

class Department {
  final int id;
  final String name;

  Department({required this.id, required this.name});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
    );
  }
}

class City {
  final int id;
  final String name;
  final int departmentId;

  City({required this.id, required this.name, required this.departmentId});

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'],
      name: json['name'],
      departmentId: json['departmentId'] ?? 0,
    );
  }
}

class ColombiaLocationService {
  static const String _baseUrl = 'https://api-colombia.com/api/v1';

  Future<List<Department>> getDepartments() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/Department'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final departments = data.map((json) => Department.fromJson(json)).toList();
        // Sort alphabetically
        departments.sort((a, b) => a.name.compareTo(b.name));
        return departments;
      } else {
        throw Exception('Failed to load departments');
      }
    } catch (e) {
      throw Exception('Error fetching departments: $e');
    }
  }

  Future<List<City>> getCitiesByDepartment(int departmentId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/Department/$departmentId/cities'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final cities = data.map((json) => City.fromJson(json)).toList();
        // Sort alphabetically
        cities.sort((a, b) => a.name.compareTo(b.name));
        return cities;
      } else {
        throw Exception('Failed to load cities');
      }
    } catch (e) {
      throw Exception('Error fetching cities: $e');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Cambiar según el entorno:
  // LOCAL: 'http://localhost/viax/backend'
  // PRODUCCIÓN: 'https://pinggo-backend-production.up.railway.app'
  const String baseUrl = 'http://localhost/viax/backend';

  print('🧪 Testing Viax Backend API');
  print('=' * 50);

  // Test 1: Health Check
  print('\n1. Testing Health Check (/)');
  try {
    final response = await http.get(Uri.parse(baseUrl));
    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Response: $data');
      print('✅ Health check passed!');
    } else {
      print('❌ Health check failed!');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 2: Verify System Endpoint (JSON)
  print('\n2. Testing Verify System Endpoint (JSON)');
  try {
    final response = await http.get(Uri.parse('$baseUrl/verify_system_json.php'));
    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Database: ${data['database']}');
      print('Available drivers: ${data['available_drivers']}');
      print('Pending requests: ${data['pending_requests']}');
      print('✅ Verify system JSON endpoint working!');
    } else {
      print('Response body: ${response.body}');
      print('❌ Verify system JSON endpoint failed!');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 3: Test Database Connection (via verify_system_json)
  print('\n3. Testing Database Connection');
  try {
    final response = await http.get(Uri.parse('$baseUrl/verify_system_json.php'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['database'] == 'connected') {
        print('✅ Database connection successful!');
        print('System components checked: ${data['system_check'].length}');
      } else {
        print('❌ Database connection failed!');
        print('Database status: ${data['database']}');
      }
    }
  } catch (e) {
    print('❌ Error testing database: $e');
  }

  // Test 5: Test User Registration
  print('\n5. Testing User Registration');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'nombre': 'Test User',
        'email': 'test${DateTime.now().millisecondsSinceEpoch}@example.com',
        'password': 'test123',
        'telefono': '1234567890',
        'tipo_usuario': 'pasajero'
      }),
    );
    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = json.decode(response.body);
        print('Response: $data');
        print('✅ User registration endpoint working!');
      } catch (e) {
        print('Response (not JSON): ${response.body}');
      }
    } else {
      print('❌ User registration failed!');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 7: Test Check Trip Requests
  print('\n7. Testing Check Trip Requests');
  try {
    final response = await http.get(Uri.parse('$baseUrl/user/check_solicitudes.php'));
    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        print('Response type: ${data.runtimeType}');
        if (data is List) {
          print('Trip requests found: ${data.length}');
          if (data.isNotEmpty) {
            print('First request: ${data[0]}');
          }
        } else if (data is Map) {
          print('Response: $data');
        }
        print('✅ Check trip requests endpoint working!');
      } catch (e) {
        print('Response (not JSON): ${response.body.substring(0, 200)}...');
        print('✅ Check trip requests endpoint responding');
      }
    } else {
      print('❌ Check trip requests endpoint failed!');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n' + '=' * 50);
  print('🧪 Backend testing completed!');
  print('Remember to replace the Railway URL with your actual deployment URL');
}
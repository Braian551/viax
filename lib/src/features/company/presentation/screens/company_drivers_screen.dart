import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/theme/app_colors.dart';
import '../widgets/company_widgets.dart';
import 'package:viax/src/features/admin/presentation/widgets/user_management_widgets.dart';

class CompanyDriversTab extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyDriversTab({super.key, required this.user});

  @override
  State<CompanyDriversTab> createState() => _CompanyDriversTabState();
}

class _CompanyDriversTabState extends State<CompanyDriversTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _drivers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Usamos el ID de la empresa si está en el objeto de usuario, si no, intentamos con user_id
      // Referencia a backend/company/pricing.php logic
      final empresaId = widget.user['empresa_id'] ?? widget.user['id']; // Fallback temporario

      final url = Uri.parse('${AppConfig.baseUrl}/company/drivers.php?empresa_id=$empresaId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _drivers = List<Map<String, dynamic>>.from(data['data']['conductores'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            ElevatedButton(onPressed: _loadDrivers, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_drivers.isEmpty) {
      return const Center(child: Text('No tienes conductores asociados.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return UserCard(
          user: driver,
          onTap: () => _showDriverDetails(driver),
        );
      },
    );
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserDetailsSheet(user: driver),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';

class ConductorRequestsScreen extends StatefulWidget {
  final int conductorId;

  const ConductorRequestsScreen({
    super.key,
    required this.conductorId,
  });

  @override
  State<ConductorRequestsScreen> createState() => _ConductorRequestsScreenState();
}

class _ConductorRequestsScreenState extends State<ConductorRequestsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAutoRefresh();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _startAutoRefresh() {
    _loadPendingRequests();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadPendingRequests();
    });
  }

  Future<void> _loadPendingRequests() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/conductor/get_pending_requests.php?conductor_id=${widget.conductorId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _pendingRequests = List<Map<String, dynamic>>.from(data['solicitudes'] ?? []);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error cargando solicitudes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/conductor/accept_trip_request.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'solicitud_id': request['id'],
          'conductor_id': widget.conductorId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Â¡Viaje aceptado! DirÃ­gete al punto de origen'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPendingRequests();
        } else {
          _showError(data['message'] ?? 'Error al aceptar viaje');
        }
      }
    } catch (e) {
      _showError('Error al aceptar viaje: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Solicitudes de viaje',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD700)),
            onPressed: _loadPendingRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFD700),
              ),
            )
          : _pendingRequests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFFFFD700),
                  onRefresh: _loadPendingRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(_pendingRequests[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.5 + (_pulseController.value * 0.5),
                child: const Icon(
                  Icons.search,
                  size: 80,
                  color: Color(0xFFFFD700),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay solicitudes disponibles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las solicitudes de viaje aparecerÃ¡n aquÃ­',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final distanciaOrigen = request['distancia_conductor_origen']?.toString() ?? '0';
    final distanciaViaje = request['distancia_km']?.toString() ?? '0';
    final duracion = request['duracion_minutos']?.toString() ?? '0';
    final precio = request['precio_estimado']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header con informaciÃ³n del usuario
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.black, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['nombre_usuario'] ?? 'Usuario',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'A ${double.parse(distanciaOrigen).toStringAsFixed(1)} km de ti',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${double.parse(precio).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Detalles del viaje
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.radio_button_checked,
                  'Origen',
                  request['direccion_origen'] ?? '',
                  const Color(0xFFFFD700),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.location_on,
                  'Destino',
                  request['direccion_destino'] ?? '',
                  Colors.red,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.straighten,
                      '${double.parse(distanciaViaje).toStringAsFixed(1)} km',
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.access_time,
                      '$duracion min',
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.motorcycle,
                      request['tipo_vehiculo'] ?? '',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // BotÃ³n de aceptar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Aceptar viaje',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

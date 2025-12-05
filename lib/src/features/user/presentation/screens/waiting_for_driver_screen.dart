import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/trip_request_service.dart';

/// Pantalla de espera mientras se busca un conductor
/// Estilo Uber/DiDi con animaciÃ³n de bÃºsqueda y polling de estado
class WaitingForDriverScreen extends StatefulWidget {
  final int solicitudId;
  final int clienteId;
  final String direccionOrigen;
  final String direccionDestino;

  const WaitingForDriverScreen({
    super.key,
    required this.solicitudId,
    required this.clienteId,
    required this.direccionOrigen,
    required this.direccionDestino,
  });

  @override
  State<WaitingForDriverScreen> createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen>
    with TickerProviderStateMixin {
  Timer? _statusTimer;
  bool _isSearching = true;
  int _searchDuration = 0;
  Timer? _durationTimer;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  
  Map<String, dynamic>? _conductorInfo;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startStatusPolling();
    _startDurationTimer();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    // AnimaciÃ³n de pulso para el icono central
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // AnimaciÃ³n de ondas expansivas
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOut,
    ));
  }

  void _startStatusPolling() {
    // Consultar estado cada 3 segundos
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkTripStatus();
    });
    
    // Primera consulta inmediata
    _checkTripStatus();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _searchDuration++;
        });
      }
    });
  }

  Future<void> _checkTripStatus() async {
    final result = await TripRequestService.getTripStatus(
      solicitudId: widget.solicitudId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final trip = result['trip'];
      final estado = trip['estado'];

      // Si el conductor aceptÃ³, navegar a pantalla de tracking
      if (estado == 'aceptada' || estado == 'conductor_asignado') {
        _statusTimer?.cancel();
        _durationTimer?.cancel();
        
        setState(() {
          _isSearching = false;
          _conductorInfo = trip['conductor'];
        });

        // Navegar a pantalla de tracking despuÃ©s de mostrar info del conductor
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/user/tracking_driver',
              arguments: {
                'solicitud_id': widget.solicitudId,
                'conductor': _conductorInfo,
              },
            );
          }
        });
      } else if (estado == 'cancelada') {
        _statusTimer?.cancel();
        _durationTimer?.cancel();
        _showCanceledDialog();
      }
    }
  }

  void _showCanceledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Solicitud Cancelada',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No se encontraron conductores disponibles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Entendido',
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
          ),
        ),
      ),
    );
  }

  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFFF00),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Â¿Cancelar Solicitud?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Â¿EstÃ¡s seguro de que deseas cancelar tu solicitud de viaje?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white24,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('No'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'SÃ­, Cancelar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFFF00),
          ),
        ),
      );

      final result = await TripRequestService.cancelTripRequestWithReason(
        solicitudId: widget.solicitudId,
        clienteId: widget.clienteId,
        motivo: 'Cliente cancelÃ³ durante bÃºsqueda',
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      if (result['success'] == true) {
        Navigator.pop(context, 'cancelled');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al cancelar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration() {
    final minutes = _searchDuration ~/ 60;
    final seconds = _searchDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header con botÃ³n de cancelar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Buscando Conductor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isSearching)
                    TextButton(
                      onPressed: _cancelTrip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        backgroundColor: Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Ãrea de animaciÃ³n central
            Expanded(
              child: Center(
                child: _isSearching
                    ? _buildSearchingAnimation()
                    : _buildDriverFoundInfo(),
              ),
            ),

            // Info del viaje en la parte inferior
            _buildTripInfoPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingAnimation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ondas expansivas
        Stack(
          alignment: Alignment.center,
          children: [
            // Onda 1
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return Container(
                  width: 200 * _waveAnimation.value,
                  height: 200 * _waveAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFFF00).withOpacity(
                        0.3 * (1 - _waveAnimation.value),
                      ),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            // Onda 2 (desfasada)
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                final value = (_waveAnimation.value + 0.33) % 1.0;
                return Container(
                  width: 200 * value,
                  height: 200 * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFFF00).withOpacity(
                        0.3 * (1 - value),
                      ),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            // Onda 3 (mÃ¡s desfasada)
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                final value = (_waveAnimation.value + 0.66) % 1.0;
                return Container(
                  width: 200 * value,
                  height: 200 * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFFF00).withOpacity(
                        0.3 * (1 - value),
                      ),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            // Icono central con pulso
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFF00),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFFF00).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.search,
                  color: Colors.black,
                  size: 50,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        // Texto de bÃºsqueda
        const Text(
          'Buscando el conductor perfecto',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tiempo de bÃºsqueda: ${_formatDuration()}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        // Indicador de progreso
        Container(
          width: 150,
          child: const LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFF00)),
            backgroundColor: Colors.white12,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverFoundInfo() {
    if (_conductorInfo == null) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Checkmark animado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Â¡Conductor Encontrado!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _conductorInfo!['nombre'] ?? 'Conductor',
          style: const TextStyle(
            color: Color(0xFFFFFF00),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        // Info del vehÃ­culo
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _conductorInfo!['vehiculo']['tipo'] == 'moto'
                        ? Icons.motorcycle
                        : Icons.directions_car,
                    color: const Color(0xFFFFFF00),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_conductorInfo!['vehiculo']['marca']} ${_conductorInfo!['vehiculo']['modelo']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Placa: ${_conductorInfo!['vehiculo']['placa']}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        border: const Border(
          top: BorderSide(
            color: Colors.white10,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Origen y destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 30,
                    color: Colors.white24,
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Origen',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.direccionOrigen,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Destino',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.direccionDestino,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

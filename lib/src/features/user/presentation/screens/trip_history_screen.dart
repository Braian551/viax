import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pantalla de historial de viajes
/// Muestra todos los viajes realizados por el usuario
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final List<Map<String, dynamic>> _trips = [
    {
      'id': '1',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'origin': 'Calle 123, BogotÃ¡',
      'destination': 'Carrera 45, BogotÃ¡',
      'distance': 5.2,
      'duration': 15,
      'price': 12500,
      'status': 'completed',
      'vehicleType': 'Standard',
      'driverName': 'Carlos RodrÃ­guez',
      'driverRating': 4.9,
      'paymentMethod': 'Tarjeta â€¢â€¢â€¢â€¢ 4242',
    },
    {
      'id': '2',
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'origin': 'Avenida 68, BogotÃ¡',
      'destination': 'Centro Comercial, BogotÃ¡',
      'distance': 8.5,
      'duration': 22,
      'price': 18000,
      'status': 'completed',
      'vehicleType': 'Premium',
      'driverName': 'MarÃ­a GonzÃ¡lez',
      'driverRating': 5.0,
      'paymentMethod': 'Efectivo',
    },
    {
      'id': '3',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'origin': 'Aeropuerto El Dorado',
      'destination': 'Hotel Tequendama',
      'distance': 15.3,
      'duration': 35,
      'price': 32000,
      'status': 'completed',
      'vehicleType': 'XL',
      'driverName': 'Pedro MartÃ­nez',
      'driverRating': 4.8,
      'paymentMethod': 'Tarjeta â€¢â€¢â€¢â€¢ 8888',
    },
    {
      'id': '4',
      'date': DateTime.now().subtract(const Duration(days: 10)),
      'origin': 'Universidad Nacional',
      'destination': 'Parque SimÃ³n BolÃ­var',
      'distance': 3.2,
      'duration': 12,
      'price': 8500,
      'status': 'cancelled',
      'vehicleType': 'Economy',
      'driverName': null,
      'driverRating': null,
      'paymentMethod': null,
    },
  ];

  String _selectedFilter = 'all';

  List<Map<String, dynamic>> get _filteredTrips {
    if (_selectedFilter == 'all') return _trips;
    return _trips.where((trip) => trip['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: _filteredTrips.isEmpty
                  ? _buildEmptyState()
                  : _buildTripsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Historial de viajes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFFFFFF00)),
            onPressed: () {
              // Mostrar opciones de filtro avanzado
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('Todos', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Completados', 'completed'),
          const SizedBox(width: 8),
          _buildFilterChip('Cancelados', 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFFF00)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFFF00)
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history,
              color: Color(0xFFFFFF00),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay viajes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tus viajes aparecerÃ¡n aquÃ­',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredTrips.length,
      itemBuilder: (context, index) {
        final trip = _filteredTrips[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTripCard(trip),
        );
      },
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final date = trip['date'] as DateTime;
    final status = trip['status'] as String;
    final isCompleted = status == 'completed';

    return GestureDetector(
      onTap: () => _showTripDetails(trip),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isCompleted ? 'Completado' : 'Cancelado',
                        style: TextStyle(
                          color: isCompleted ? Colors.green : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        Container(
                          width: 10,
                          height: 10,
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
                          Text(
                            trip['origin'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            trip['destination'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTripStat(
                        Icons.straighten,
                        '${trip['distance']} km',
                      ),
                      _buildTripStat(
                        Icons.access_time,
                        '${trip['duration']} min',
                      ),
                      _buildTripStat(
                        Icons.attach_money,
                        '\$${trip['price']}',
                        highlight: true,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String value, {bool highlight = false}) {
    return Row(
      children: [
        Icon(
          icon,
          color:
              highlight ? const Color(0xFFFFFF00) : Colors.white.withValues(alpha: 0.6),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFFFFFF00) : Colors.white,
            fontSize: 13,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTripDetailsSheet(trip),
    );
  }

  Widget _buildTripDetailsSheet(Map<String, dynamic> trip) {
    final isCompleted = trip['status'] == 'completed';

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Detalles del viaje',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    'InformaciÃ³n del viaje',
                    [
                      _buildDetailRow('Origen', trip['origin']),
                      _buildDetailRow('Destino', trip['destination']),
                      if (isCompleted) ...[
                        _buildDetailRow('Distancia', '${trip['distance']} km'),
                        _buildDetailRow('DuraciÃ³n', '${trip['duration']} min'),
                        _buildDetailRow('CategorÃ­a', trip['vehicleType']),
                      ],
                    ],
                  ),
                  if (isCompleted) ...[
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      'Conductor',
                      [
                        _buildDetailRow('Nombre', trip['driverName']),
                        _buildDetailRow(
                          'CalificaciÃ³n',
                          '${trip['driverRating']} â­',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      'Pago',
                      [
                        _buildDetailRow('MÃ©todo', trip['paymentMethod']),
                        _buildDetailRow('Total', '\$${trip['price']}', highlight: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (isCompleted) ...[
                    _buildActionButton(
                      'Descargar recibo',
                      Icons.receipt,
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Descargando recibo...'),
                            backgroundColor: Colors.black87,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      'Reportar problema',
                      Icons.report_problem_outlined,
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _showReportDialog();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFFFFF00),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFFFFF00) : Colors.white,
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon, {
    Color? color,
    required VoidCallback onTap,
  }) {
    final buttonColor = color ?? const Color(0xFFFFFF00);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: buttonColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: buttonColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: buttonColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: buttonColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Reportar problema',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Â¿QuÃ© problema experimentaste con este viaje?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reporte enviado. Te contactaremos pronto.'),
                  backgroundColor: Colors.black87,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Enviar',
              style: TextStyle(color: Color(0xFFFFFF00)),
            ),
          ),
        ],
      ),
    );
  }
}

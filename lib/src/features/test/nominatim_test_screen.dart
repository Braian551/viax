import 'package:flutter/material.dart';
import 'package:viax/src/global/services/nominatim_service.dart';
import 'package:latlong2/latlong.dart';

/// Script de prueba para verificar bÃºsquedas en Nominatim
/// Ejecuta este widget para probar diferentes bÃºsquedas
class NominatimTestScreen extends StatefulWidget {
  const NominatimTestScreen({super.key});

  @override
  State<NominatimTestScreen> createState() => _NominatimTestScreenState();
}

class _NominatimTestScreenState extends State<NominatimTestScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<NominatimResult> _results = [];
  bool _isLoading = false;
  String? _error;

  // Ubicaciones de prueba
  final Map<String, LatLng> _testLocations = {
    'San Gil, Santander': LatLng(6.5561, -73.1339),
    'MedellÃ­n': LatLng(6.2442, -75.5812),
    'BogotÃ¡': LatLng(4.6097, -74.0817),
  };

  LatLng? _selectedProximity;

  final List<String> _testQueries = [
    'Colegio La Primavera MedellÃ­n',
    'Parque El Gallineral',
    'Hospital San Gil',
    'Plaza Botero MedellÃ­n',
    'Parque SimÃ³n BolÃ­var',
    'Terminal de Transportes San Gil',
    'Universidad Nacional BogotÃ¡',
    'JardÃ­n BotÃ¡nico MedellÃ­n',
  ];

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final results = await NominatimService.searchAddress(
        _searchController.text,
        proximity: _selectedProximity,
        limit: 10,
      );

      setState(() {
        _results = results;
        _isLoading = false;
      });

      if (results.isEmpty) {
        setState(() {
          _error = 'No se encontraron resultados';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Prueba Nominatim API',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Panel de control
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo de bÃºsqueda
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar lugar en Colombia...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Selector de ubicaciÃ³n de prueba
                const Text(
                  'Proximidad (opcional):',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in _testLocations.entries)
                      FilterChip(
                        label: Text(entry.key),
                        selected: _selectedProximity == entry.value,
                        onSelected: (selected) {
                          setState(() {
                            _selectedProximity = selected ? entry.value : null;
                          });
                        },
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        selectedColor: const Color(0xFFFFD700),
                        labelStyle: TextStyle(
                          color: _selectedProximity == entry.value
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // BÃºsquedas rÃ¡pidas
                const Text(
                  'BÃºsquedas de prueba:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final query in _testQueries)
                      ActionChip(
                        label: Text(
                          query,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          _searchController.text = query;
                          _search();
                        },
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Resultados
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFD700),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.withValues(alpha: 0.7),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 64,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Realiza una bÃºsqueda para probar',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final result = _results[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFD700)
                                              .withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Color(0xFFFFD700),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            result.getShortName(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFD700)
                                              .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '#${index + 1}',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      result.getFormattedAddress(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildInfoChip(
                                          'ðŸ“ ${result.lat.toStringAsFixed(4)}, ${result.lon.toStringAsFixed(4)}',
                                        ),
                                        if (result.type != null) ...[
                                          const SizedBox(width: 8),
                                          _buildInfoChip('ðŸ·ï¸ ${result.type}'),
                                        ],
                                      ],
                                    ),
                                    if (result.getCity() != null) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoChip(
                                        'ðŸ™ï¸ ${result.getCity()}',
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
          ),

          // Resumen
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resultados: ${_results.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (_selectedProximity != null)
                  Row(
                    children: [
                      Icon(
                        Icons.near_me,
                        color: const Color(0xFFFFD700),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Con proximidad',
                        style: TextStyle(
                          color: const Color(0xFFFFD700),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 11,
        ),
      ),
    );
  }
}

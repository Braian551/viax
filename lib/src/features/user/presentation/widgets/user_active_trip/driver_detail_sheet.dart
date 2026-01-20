import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../conductor/services/document_upload_service.dart';

import 'package:viax/src/global/services/rating_service.dart';

class DriverDetailSheet extends StatefulWidget {
  final Map<String, dynamic> conductor;
  final bool isDark;
  final ScrollController? scrollController;

  const DriverDetailSheet({
    super.key,
    required this.conductor,
    required this.isDark,
    this.scrollController,
  });

  @override
  State<DriverDetailSheet> createState() => _DriverDetailSheetState();
}

class _DriverDetailSheetState extends State<DriverDetailSheet> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingFn = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    debugPrint('🔍 [DriverDetailSheet] Conductor data: ${widget.conductor}');
    final conductorId = widget.conductor['id'] ?? widget.conductor['id_conductor'];
    debugPrint('🔍 [DriverDetailSheet] Conductor ID: $conductorId');
    
    if (conductorId == null) {
      debugPrint('🔍 [DriverDetailSheet] Conductor ID is null, aborting');
      if (mounted) setState(() => _isLoadingFn = false);
      return;
    }

    // Convertir ID a entero si viene como string
    final idInt = conductorId is String ? int.tryParse(conductorId) : conductorId as int?;
    debugPrint('🔍 [DriverDetailSheet] ID as int: $idInt');
    
    if (idInt == null) {
        debugPrint('🔍 [DriverDetailSheet] Could not parse ID to int');
        if (mounted) setState(() => _isLoadingFn = false);
        return;
    }

    try {
      final response = await RatingService.obtenerCalificaciones(
        usuarioId: idInt,
        tipoUsuario: 'conductor',
        limit: 10,
      );

      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _reviews = List<Map<String, dynamic>>.from(response['calificaciones'] ?? []);
          }
          _isLoadingFn = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) setState(() => _isLoadingFn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conductorNombre = widget.conductor['nombre'] as String? ?? 'Conductor';
    final conductorFoto = widget.conductor['foto'];
    // Intentar obtener calificacion de varios campos posibles
    final calificacion = (widget.conductor['calificacion_promedio'] as num?)?.toDouble() 
        ?? (widget.conductor['calificacion'] as num?)?.toDouble() 
        ?? 5.0;
    final vehiculo = widget.conductor['vehiculo'] as Map<String, dynamic>?;
    final vehiculoInfo = vehiculo != null
        ? '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'.trim()
        : 'Vehículo no especificado';
    final placa = vehiculo?['placa'] as String? ?? '';
    
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Flexible(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 10),
                
                // Foto grande
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                      image: DecorationImage(
                        image: conductorFoto != null
                            ? NetworkImage(DocumentUploadService.getDocumentUrl(conductorFoto))
                            : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                        fit: BoxFit.cover,
                        onError: (_, __) {},
                      ),
                    ),
                    child: conductorFoto == null
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Nombre
                Text(
                  conductorNombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Rating badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            calificacion.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Vehículo info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehiculoInfo,
                            style: TextStyle(
                              color: widget.isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (placa.isNotEmpty)
                            Text(
                              placa,
                              style: TextStyle(
                                color: widget.isDark ? Colors.white60 : Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Reseñas header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reseñas de usuarios',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_reviews.length > 3)
                      TextButton(
                        onPressed: _showAllReviews,
                        child: Text(
                          'Ver todas (${_reviews.length})',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Lista de reseñas (máximo 3)
                if (_isLoadingFn)
                  const Center(child: CircularProgressIndicator())
                else if (_reviews.isEmpty)
                   Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Aún no hay reseñas',
                        style: TextStyle(
                          color: widget.isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ),
                  )
                else
                  ..._reviews.take(3).map((review) => _buildReviewItem(review, widget.isDark)),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Todas las reseñas (${_reviews.length})',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: widget.isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Lista completa de reseñas
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) => 
                      _buildReviewItem(_reviews[index], widget.isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review, bool isDark) {
    final nombre = review['nombre_calificador'] ?? 'Usuario';
    final fecha = review['fecha_calificacion'] ?? ''; // Formatear fecha si es necesario
    final comentario = review['comentario'] as String? ?? '';
    final rating = (review['calificacion'] as num?)?.toDouble() ?? 5.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nombre,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (fecha.isNotEmpty)
                Text(
                  // Podrías usar intl para formatear "hace X días"
                  fecha.toString().substring(0, 10), 
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          if (comentario.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comentario,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

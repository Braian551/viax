import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../../theme/app_colors.dart';
import '../../../domain/models/company_vehicle_models.dart';
import '../../../data/services/company_vehicle_service.dart';

/// Sheet para mostrar información detallada de una empresa
class CompanyDetailsSheet extends StatefulWidget {
  const CompanyDetailsSheet({
    super.key,
    required this.empresaId,
    required this.isDark,
  });

  final int empresaId;
  final bool isDark;

  @override
  State<CompanyDetailsSheet> createState() => _CompanyDetailsSheetState();
}

class _CompanyDetailsSheetState extends State<CompanyDetailsSheet> {
  CompanyDetails? _details;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await CompanyVehicleService.getCompanyDetails(widget.empresaId);
      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
          if (details == null) {
            _error = 'No se pudo cargar la información';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error de conexión';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark 
                ? const Color(0xFF1A1A1A).withValues(alpha: 0.9) 
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: _isLoading
                        ? _buildLoading()
                        : _error != null
                            ? _buildError()
                            : _buildContent(scrollController),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando información...',
            style: TextStyle(
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final details = _details!;
    
    return ListView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      children: [
        // Header with Logo and Name
        _buildHeader(details),
        const SizedBox(height: 24),
        
        // Rating Card
        if (details.calificacionPromedio != null)
          _buildRatingCard(details),
        
        const SizedBox(height: 16),
        
        // Stats Grid
        _buildStatsGrid(details),
        const SizedBox(height: 24),
        
        // Description
        if (details.descripcion != null && details.descripcion!.isNotEmpty)
          _buildSection(
            icon: Icons.info_outline_rounded,
            title: 'Acerca de',
            child: Text(
              details.descripcion!,
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        
        // Vehicle Types
        if (details.tiposVehiculo.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.directions_car_rounded,
            title: 'Tipos de vehículo',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: details.tiposVehiculo.map((tipo) {
                return Chip(
                  label: Text(tipo.nombre),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        
        // Contact Info
        if (details.telefono != null || details.email != null) ...[
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.contact_phone_rounded,
            title: 'Contacto',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.telefono != null)
                  _buildContactRow(Icons.phone, details.telefono!),
                if (details.email != null)
                  _buildContactRow(Icons.email_outlined, details.email!),
                if (details.website != null)
                  _buildContactRow(Icons.language, details.website!),
              ],
            ),
          ),
        ],
        
        // Location
        if (details.municipio != null) ...[
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.location_on_outlined,
            title: 'Ubicación',
            child: Text(
              '${details.municipio}${details.departamento != null ? ', ${details.departamento}' : ''}',
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(CompanyDetails details) {
    return Row(
      children: [
        Hero(
          tag: 'company_logo_${details.id}',
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: details.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(details.logoUrl!, fit: BoxFit.cover),
                  )
                : Icon(Icons.business_rounded, size: 36, color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      details.nombre,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (details.verificada) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.verified_rounded, color: AppColors.primary, size: 22),
                  ],
                ],
              ),
              if (details.anioFundacion != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Desde ${details.anioFundacion}',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white54 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingCard(CompanyDetails details) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Big Star + Rating
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded, color: AppColors.warning, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      details.calificacionPromedio!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      ' / 5',
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${details.totalCalificaciones} calificaciones',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Stars
          Column(
            children: List.generate(5, (index) {
              final starValue = 5 - index;
              final isFilled = details.calificacionPromedio! >= starValue - 0.5;
              return Icon(
                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFilled ? AppColors.warning : (widget.isDark ? Colors.white24 : Colors.black12),
                size: 16,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(CompanyDetails details) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.directions_car_filled_rounded,
            value: '${details.totalConductores}',
            label: 'Conductores',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.route_rounded,
            value: '${details.viajesCompletados}',
            label: 'Viajes',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: widget.isDark ? Colors.white54 : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: widget.isDark ? Colors.white54 : Colors.black54, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: widget.isDark ? Colors.white54 : Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

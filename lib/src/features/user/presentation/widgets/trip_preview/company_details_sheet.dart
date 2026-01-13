import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../../theme/app_colors.dart';
import '../../../domain/models/company_vehicle_models.dart';
import '../../../data/services/company_vehicle_service.dart';

/// Sheet para mostrar información detallada de una empresa - Rediseño Final Vibrant
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
    final isDark = widget.isDark;
    
    // Background con gradiente muy sutil y glass
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark 
          ? [const Color(0xFF252525).withValues(alpha: 0.95), const Color(0xFF151515).withValues(alpha: 0.98)]
          : [const Color(0xFFFFFFFF).withValues(alpha: 0.95), const Color(0xFFF8F9FA).withValues(alpha: 0.98)],
    );

    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: bgGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle Premium
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 8),
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.5), AppColors.primary]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? _buildLoading()
                        : _error != null
                            ? _buildError(textColor)
                            : _buildContent(scrollController, textColor, subTextColor, isDark),
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
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildError(Color textColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: textColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ScrollController scrollController,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    final details = _details!;
    
    return ListView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
      children: [
        // 1. Header con Logo Cuadrado (Rounded)
        Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade100,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: details.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(details.logoUrl!, fit: BoxFit.contain),
                    )
                  : Icon(Icons.business_rounded, color: Colors.grey.shade400, size: 40),
            ),
            const SizedBox(width: 20),
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
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (details.verificada) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.verified_rounded, color: AppColors.primary, size: 24),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Rating Badge Elegante
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          details.calificacionPromedio?.toStringAsFixed(1) ?? 'N/A',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: subTextColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '${details.totalCalificaciones} reseñas',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // 2. Stats Section - Estilo Bloque Premium con Color Sólido
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.06) 
                  : Colors.grey.withValues(alpha: 0.08),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildElegantStat(
                    'Viajes',
                    '${details.viajesCompletados}',
                    Icons.route_outlined,
                    Colors.purpleAccent,
                    textColor,
                    subTextColor,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                ),
                Expanded(
                  child: _buildElegantStat(
                    'Conductores',
                    '${details.totalConductores}',
                    Icons.people_outline_rounded,
                    AppColors.primary,
                    textColor,
                    subTextColor,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                ),
                Expanded(
                  child: _buildElegantStat(
                    'Rating',
                    details.calificacionPromedio?.toStringAsFixed(1) ?? '-',
                    Icons.star_outline_rounded,
                    AppColors.warning,
                    textColor,
                    subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // 3. Flota Disponible - Pills con Gradiente Vivo
        if (details.tiposVehiculo.isNotEmpty) ...[
          _buildSectionHeader('FLOTA DISPONIBLE', subTextColor),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: details.tiposVehiculo.map((tipo) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50), // Pill shape
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                     BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getVehicleIcon(tipo.nombre),
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tipo.nombre,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],

        // 4. Acerca de - Diseño limpio sin caja gris
        if (details.descripcion != null && details.descripcion!.isNotEmpty) ...[
          _buildSectionHeader('ACERCA DE', subTextColor),
          const SizedBox(height: 12),
          Text(
            details.descripcion!,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
        ],

        // 5. Contacto - Action Box Cards (Grid de opciones coloridas)
        if (details.telefono != null || details.email != null || details.municipio != null) ...[
          _buildSectionHeader('CONTACTO', subTextColor),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna principal con info
              Expanded(
                child: Column(
                  children: [
                    if (details.municipio != null)
                      _buildContactRowModern(
                        Icons.map_outlined, 
                        'Ubicación',
                        '${details.municipio}, ${details.departamento ?? ""}',
                        Colors.blue,
                        isDark,
                        textColor,
                      ),
                    const SizedBox(height: 16),
                    if (details.telefono != null)
                      _buildContactRowModern(
                        Icons.phone_in_talk, 
                        'Teléfono',
                        details.telefono!,
                        Colors.green,
                        isDark,
                        textColor,
                      ),
                    const SizedBox(height: 16),
                    if (details.email != null)
                      _buildContactRowModern(
                        Icons.email_outlined, 
                        'Email',
                        details.email!,
                        Colors.orangeAccent,
                        isDark,
                        textColor,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildElegantStat(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: subTextColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildContactRowModern(
    IconData icon,
    String label,
    String value,
    Color iconColor,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black12),
        ],
      ),
    );
  }
  
  IconData _getVehicleIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('moto') && !lower.contains('carro')) return Icons.two_wheeler_rounded;
    if (lower.contains('auto') || lower.contains('carro')) return Icons.directions_car_rounded;
    if (lower.contains('taxi')) return Icons.local_taxi_rounded;
    return Icons.directions_transit_rounded;
  }
}

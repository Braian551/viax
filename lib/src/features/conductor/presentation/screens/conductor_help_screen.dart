import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/help/help_widgets.dart';
import '../widgets/conductor_drawer.dart';

/// Pantalla de Ayuda y Soporte para conductores
class ConductorHelpScreen extends StatefulWidget {
  final int conductorId;
  final Map<String, dynamic>? conductorUser;

  const ConductorHelpScreen({
    super.key,
    required this.conductorId,
    this.conductorUser,
  });

  @override
  State<ConductorHelpScreen> createState() => _ConductorHelpScreenState();
}

class _ConductorHelpScreenState extends State<ConductorHelpScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedCategory = 'Todos';

  final List<Map<String, String>> _faqs = [
    {
      'category': 'Viajes',
      'question': '¿Cómo acepto un viaje?',
      'answer':
          'Cuando recibas una solicitud de viaje, verás una notificación con los detalles. Toca "Aceptar" para confirmar el viaje. Asegúrate de estar en línea y con ubicación activa.',
    },
    {
      'category': 'Viajes',
      'question': '¿Cómo cancelo un viaje?',
      'answer':
          'Puedes cancelar un viaje desde la pantalla de viaje activo tocando el botón de cancelar. Ten en cuenta que cancelaciones frecuentes pueden afectar tu calificación.',
    },
    {
      'category': 'Pagos',
      'question': '¿Cuándo recibo mis pagos?',
      'answer':
          'Los pagos se procesan semanalmente. Recibirás tu pago cada lunes por los viajes realizados la semana anterior. Puedes ver el estado de tus pagos en la sección de Ganancias.',
    },
    {
      'category': 'Pagos',
      'question': '¿Cómo cambio mi método de pago?',
      'answer':
          'Ve a Configuración > Pagos > Método de cobro. Desde ahí puedes actualizar tu cuenta bancaria o agregar una nueva.',
    },
    {
      'category': 'Cuenta',
      'question': '¿Cómo actualizo mis documentos?',
      'answer':
          'Ve a Documentos desde el menú principal. Ahí podrás ver el estado de cada documento y subir nuevas versiones cuando sea necesario.',
    },
    {
      'category': 'Cuenta',
      'question': '¿Cómo cambio mi foto de perfil?',
      'answer':
          'Ve a Configuración > Mi cuenta > Editar perfil. Toca en tu foto actual para seleccionar una nueva imagen desde tu galería o cámara.',
    },
    {
      'category': 'Vehículo',
      'question': '¿Cómo registro un nuevo vehículo?',
      'answer':
          'Ve a Mi Vehículo desde el menú. Si no tienes un vehículo registrado, verás la opción de registrar uno nuevo. Sigue los pasos y sube la documentación requerida.',
    },
    {
      'category': 'Vehículo',
      'question': '¿Puedo usar varios vehículos?',
      'answer':
          'Actualmente solo puedes tener un vehículo activo. Si necesitas cambiar de vehículo, contacta a soporte para actualizar tu registro.',
    },
    {
      'category': 'Seguridad',
      'question': '¿Qué hago en caso de accidente?',
      'answer':
          'Primero asegúrate de que todos estén bien. Luego contacta a emergencias si es necesario. Usa el botón de emergencia en la app para notificar a soporte inmediatamente.',
    },
    {
      'category': 'Seguridad',
      'question': '¿Cómo reporto un problema con un pasajero?',
      'answer':
          'Después de finalizar el viaje, ve a tu historial y selecciona el viaje. Usa la opción "Reportar problema" para describir la situación.',
    },
  ];

  final List<String> _categories = [
    'Todos',
    'Viajes',
    'Pagos',
    'Cuenta',
    'Vehículo',
    'Seguridad'
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredFaqs {
    if (_selectedCategory == 'Todos') return _faqs;
    return _faqs.where((faq) => faq['category'] == _selectedCategory).toList();
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Soporte VIAX Conductor'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat() {
    // Aquí iría la lógica para abrir el chat de soporte
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Abriendo chat de soporte...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.emergency_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            const Text('Emergencia'),
          ],
        ),
        content: const Text(
          '¿Estás en una situación de emergencia? Esto contactará inmediatamente a nuestro equipo de seguridad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchPhone('911');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Llamar ahora'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: widget.conductorUser != null
          ? ConductorDrawer(conductorUser: widget.conductorUser!)
          : null,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          // AppBar con glassmorphism
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: isDark
                ? AppColors.darkBackground.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.8),
            leading: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_rounded,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: AnimatedBuilder(
                animation: _headerController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _headerFadeAnimation,
                    child: SlideTransition(
                      position: _headerSlideAnimation,
                      child: Text(
                        'Ayuda y Soporte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradiente de fondo
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.success.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                  // Glassmorphism effect
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  // Icono decorativo
                  Positioned(
                    right: 30,
                    top: 60,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(
                        Icons.support_agent_rounded,
                        size: 120,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de emergencia
                  EmergencyBanner(
                    onEmergencyCall: _handleEmergency,
                  ),

                  const SizedBox(height: 24),

                  // Sección de contacto
                  Text(
                    'Contáctanos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid de opciones de contacto
                  Row(
                    children: [
                      Expanded(
                        child: SupportContactCard(
                          icon: Icons.phone_rounded,
                          title: 'Teléfono',
                          subtitle: 'Lun-Sab 8am-8pm',
                          iconColor: AppColors.success,
                          onTap: () => _launchPhone('+1234567890'),
                          animationIndex: 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SupportContactCard(
                          icon: Icons.email_rounded,
                          title: 'Email',
                          subtitle: 'Respuesta en 24h',
                          iconColor: AppColors.primary,
                          onTap: () => _launchEmail('soporte@viax.com'),
                          animationIndex: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SupportContactCard(
                          icon: Icons.chat_rounded,
                          title: 'Chat',
                          subtitle: 'Soporte en vivo',
                          iconColor: Colors.purple,
                          onTap: _openChat,
                          animationIndex: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SupportContactCard(
                          icon: Icons.headset_mic_rounded,
                          title: 'Callback',
                          subtitle: 'Te llamamos',
                          iconColor: Colors.orange,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Solicitud de callback enviada'),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          animationIndex: 3,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Sección de FAQ
                  Text(
                    'Preguntas Frecuentes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filtro de categorías
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (context2, index2) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = category == _selectedCategory;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = category);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkCard
                                      : Colors.grey.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white70
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Lista de FAQs
                  ..._filteredFaqs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final faq = entry.value;
                    return FaqItem(
                      question: faq['question']!,
                      answer: faq['answer']!,
                      animationIndex: index,
                    );
                  }),

                  const SizedBox(height: 24),

                  // Botón de más ayuda
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard.withValues(alpha: 0.6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.help_center_rounded,
                          size: 48,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '¿No encontraste lo que buscabas?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Visita nuestro centro de ayuda completo',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Abrir centro de ayuda web
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Ver centro de ayuda'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

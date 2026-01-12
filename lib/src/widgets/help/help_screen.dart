import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/help/help_widgets.dart';
import 'package:viax/src/features/support/presentation/screens/support_tickets_screen.dart';
import 'package:viax/src/features/support/services/support_service.dart';

/// Tipos de usuario soportados
enum HelpUserType { user, conductor, company }

/// Pantalla de Ayuda y Soporte compartida
/// 
/// Puede ser utilizada por usuarios, conductores y empresas.
/// Las FAQs se adaptan según el tipo de usuario.
class HelpScreen extends StatefulWidget {
  final HelpUserType userType;
  final String? userName;
  final int? userId;

  const HelpScreen({
    super.key,
    this.userType = HelpUserType.user,
    this.userName,
    this.userId,
  });

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  String _selectedCategory = 'Todos';

  // FAQs generales (aplicables a todos)
  final List<Map<String, String>> _generalFaqs = [
    {
      'category': 'Cuenta',
      'question': '¿Cómo cambio mi foto de perfil?',
      'answer':
          'Ve a tu Perfil > Editar Perfil. Toca en tu foto actual para seleccionar una nueva imagen desde tu galería o cámara.',
    },
    {
      'category': 'Cuenta',
      'question': '¿Cómo actualizo mis datos personales?',
      'answer':
          'Ve a tu Perfil > Editar Perfil. Desde ahí puedes modificar tu nombre, apellido y foto de perfil.',
    },
    {
      'category': 'Seguridad',
      'question': '¿Cómo cierro sesión?',
      'answer':
          'Ve a tu Perfil y toca el botón "Cerrar Sesión" al final de la pantalla.',
    },
  ];

  // FAQs específicas para usuarios/clientes
  final List<Map<String, String>> _userFaqs = [
    {
      'category': 'Viajes',
      'question': '¿Cómo solicito un viaje?',
      'answer':
          'Desde la pantalla principal, ingresa tu destino en la barra de búsqueda. Selecciona el tipo de vehículo y confirma tu solicitud.',
    },
    {
      'category': 'Viajes',
      'question': '¿Cómo cancelo un viaje?',
      'answer':
          'Si el conductor aún no ha llegado, puedes cancelar desde la pantalla de espera tocando "Cancelar viaje". Ten en cuenta que cancelaciones frecuentes pueden afectar tu calificación.',
    },
    {
      'category': 'Pagos',
      'question': '¿Qué métodos de pago aceptan?',
      'answer':
          'Actualmente aceptamos pago en efectivo. Pronto agregaremos más métodos de pago.',
    },
    {
      'category': 'Seguridad',
      'question': '¿Cómo reporto un problema con mi viaje?',
      'answer':
          'Ve a tu historial de viajes, selecciona el viaje en cuestión y usa la opción "Reportar problema" para describir la situación.',
    },
  ];

  // FAQs específicas para conductores
  final List<Map<String, String>> _conductorFaqs = [
    {
      'category': 'Viajes',
      'question': '¿Cómo acepto un viaje?',
      'answer':
          'Cuando recibas una solicitud de viaje, verás una notificación con los detalles. Toca "Aceptar" para confirmar el viaje. Asegúrate de estar en línea y con ubicación activa.',
    },
    {
      'category': 'Pagos',
      'question': '¿Cuándo recibo mis pagos?',
      'answer':
          'Los pagos se procesan semanalmente. Recibirás tu pago cada lunes por los viajes realizados la semana anterior.',
    },
    {
      'category': 'Documentos',
      'question': '¿Cómo actualizo mis documentos?',
      'answer':
          'Ve a Documentos desde el menú principal. Ahí podrás ver el estado de cada documento y subir nuevas versiones cuando sea necesario.',
    },
    {
      'category': 'Vehículo',
      'question': '¿Cómo registro un nuevo vehículo?',
      'answer':
          'Ve a Mi Vehículo desde el menú. Si no tienes un vehículo registrado, verás la opción de registrar uno nuevo.',
    },
  ];

  // FAQs específicas para empresas
  final List<Map<String, String>> _companyFaqs = [
    {
      'category': 'Conductores',
      'question': '¿Cómo agrego conductores a mi empresa?',
      'answer':
          'Los conductores pueden registrarse y seleccionar tu empresa durante su proceso de registro. Luego aparecerán en tu lista de conductores.',
    },
    {
      'category': 'Facturación',
      'question': '¿Cómo veo los reportes de mi empresa?',
      'answer':
          'Desde el menú principal, ve a Reportes para ver estadísticas de viajes, ganancias y rendimiento de tus conductores.',
    },
  ];

  List<Map<String, String>> get _faqs {
    List<Map<String, String>> faqs = [..._generalFaqs];
    switch (widget.userType) {
      case HelpUserType.user:
        faqs.addAll(_userFaqs);
        break;
      case HelpUserType.conductor:
        faqs.addAll(_conductorFaqs);
        break;
      case HelpUserType.company:
        faqs.addAll(_companyFaqs);
        break;
    }
    return faqs;
  }

  List<String> get _categories {
    final cats = <String>{'Todos'};
    for (var faq in _faqs) {
      cats.add(faq['category']!);
    }
    return cats.toList();
  }

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
    final subject = switch (widget.userType) {
      HelpUserType.user => 'Soporte VIAX Usuario',
      HelpUserType.conductor => 'Soporte VIAX Conductor',
      HelpUserType.company => 'Soporte VIAX Empresa',
    };
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': subject},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat() {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inicia sesión para usar el chat'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportTicketsScreen(userId: widget.userId!),
      ),
    );
  }

  void _handleCallback() {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inicia sesión para solicitar callback'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    _showCallbackDialog();
  }

  void _showCallbackDialog() {
    final phoneController = TextEditingController();
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Solicitar llamada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Te contactaremos en las próximas horas',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de teléfono',
                  prefixIcon: const Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motivo (opcional)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final phone = phoneController.text.trim();
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Ingresa tu número de teléfono'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      return;
                    }

                    final success = await SupportService.requestCallback(
                      userId: widget.userId!,
                      phone: phone,
                      reason: reasonController.text.trim().isEmpty
                          ? null
                          : reasonController.text.trim(),
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Solicitud enviada. Te contactaremos pronto.'
                              : 'Error al enviar solicitud'),
                          backgroundColor: success ? AppColors.success : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Solicitar llamada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
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
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  size: 18,
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
                          onTap: () => _launchPhone('+573001234567'),
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
                          onTap: _handleCallback,
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
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
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

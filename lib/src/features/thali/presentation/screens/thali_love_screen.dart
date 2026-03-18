import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/features/thali/presentation/theme/thali_colors.dart';
import 'package:viax/src/features/thali/presentation/widgets/floating_hearts_overlay.dart';
import 'package:viax/src/features/thali/presentation/widgets/love_message_card.dart';
import 'package:viax/src/features/thali/presentation/widgets/love_promise_carousel.dart';
import 'package:viax/src/features/thali/presentation/widgets/love_story_timeline.dart';
import 'package:viax/src/features/thali/presentation/widgets/memory_capsules_grid.dart';
import 'package:viax/src/features/thali/presentation/widgets/pulsing_heart.dart';
import 'package:viax/src/features/thali/services/thali_music_service.dart';

class ThaliLoveScreen extends StatefulWidget {
  const ThaliLoveScreen({super.key});

  @override
  State<ThaliLoveScreen> createState() => _ThaliLoveScreenState();
}

class _ThaliLoveScreenState extends State<ThaliLoveScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _storyKey = GlobalKey();
  final GlobalKey _feelingsKey = GlobalKey();
  final GlobalKey _memoriesKey = GlobalKey();
  final GlobalKey _promisesKey = GlobalKey();
  bool _musicPlaying = false;
  bool _showContent = false;
  bool _showIntro = true;
  bool _letterOpened = false;

  static const _kuromiImages = [
    'assets/images/thali/kuromi1.jpg',
    'assets/images/thali/kuromi2.jpg',
    'assets/images/thali/kuromi3.jpg',
    'assets/images/thali/kuromi4.jpg',
  ];

  static const _milestones = [
    StoryMilestone(
      title: 'Junio 2025 — El comienzo',
      description:
          'Me escribiste por Instagram preguntándome si amigábamos. Acepté sin pensarlo mucho... sin saber que ese simple mensaje iba a cambiarme la vida para siempre.',
      icon: Icons.chat_bubble_rounded,
    ),
    StoryMilestone(
      title: 'Conociéndote',
      description:
          'Entre más te conocía, más me enamoraba. Cada conversación, cada risa, cada detalle tuyo me fue robando el corazón sin que me diera cuenta.',
      icon: Icons.auto_awesome,
    ),
    StoryMilestone(
      title: 'El momento que me enamoró',
      description:
          'Te bloqueé, e hiciste lo imposible para hablarme. Hasta con el celular de tu tía me llamaste. Ahí supe que esto era real, que no eras como las demás. Me enamoraste por completo.',
      icon: Icons.phone_callback_rounded,
    ),
    StoryMilestone(
      title: 'Juntos al fin',
      description:
          'A pesar del caos, a pesar de todo, terminamos juntos. Y fui el hombre más feliz del mundo. Tú eras mi paz en medio de la tormenta.',
      icon: Icons.favorite_rounded,
    ),
    StoryMilestone(
      title: 'Tormentas y regresos',
      description:
          'Nos separamos, volvimos, nos separamos otra vez. Pero cada vez que me alejaba, el universo me traía de vuelta a ti. Porque esto que sentimos es más fuerte que cualquier miedo.',
      icon: Icons.cyclone_rounded,
    ),
    StoryMilestone(
      title: 'El amor que todo lo puede',
      description:
          'Después de todo lo que pasamos, sé con certeza absoluta que eres el amor de mi vida. Cada obstáculo solo demostró que lo nuestro es irrompible.',
      icon: Icons.diamond_rounded,
    ),
    StoryMilestone(
      title: 'Hoy — Esperándote',
      description:
          'Te doy tu tiempo para sanar, porque te amo tanto que tu bienestar es mi prioridad. No somos novios todavía, pero nos tratamos como si lo fuéramos, porque el amor que sentimos no necesita etiquetas.',
      icon: Icons.hourglass_bottom_rounded,
    ),
    StoryMilestone(
      title: 'Para siempre',
      description:
          'Este regalo queda grabado aquí para siempre, como prueba de que existió alguien que te amó con todo su ser. Pase lo que pase, este recuerdo es eterno.',
      icon: Icons.all_inclusive_rounded,
    ),
  ];

  static const _memories = [
    MemoryCapsule(
      title: 'Primer mensaje',
      preview: 'El mensaje que cambió todo...',
      fullText:
          'Me escribiste por Instagram para amigarnos, y ese instante fue el inicio de un camino que me transformó por completo. Lo que parecía algo pequeño se volvió lo más grande de mi vida.',
      icon: Icons.mail_rounded,
    ),
    MemoryCapsule(
      title: 'La llamada',
      preview: 'Cuando hiciste lo imposible...',
      fullText:
          'Cuando te bloqueé y aun así buscaste cómo llamarme, incluso con el celular de tu tía, entendí que había algo único entre nosotros. Ese momento vive tatuado en mi corazón.',
      icon: Icons.phone_in_talk_rounded,
    ),
    MemoryCapsule(
      title: 'Volver a ti',
      preview: 'Siempre regresas a mi corazón.',
      fullText:
          'Nos alejamos más de una vez, pero siempre terminé volviendo a ti. Porque contigo todo tiene sentido. Porque no importa la distancia, mi amor por ti siempre encuentra el camino de regreso.',
      icon: Icons.replay_rounded,
    ),
    MemoryCapsule(
      title: 'Brillo en mis ojos',
      preview: 'Lo que tú despertaste en mí.',
      fullText:
          'Le devolviste luz a mi mirada y alegría a mis días. Donde antes había cansancio, hoy hay esperanza. Donde antes había silencio, hoy está tu nombre sonando en mi corazón.',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  static const _promises = [
    LovePromise(
      title: 'Promesa de paciencia',
      text:
          'Voy a respetar tus tiempos y tu proceso de sanar. Tu paz es importante para mí.',
      icon: Icons.hourglass_top_rounded,
    ),
    LovePromise(
      title: 'Promesa de presencia',
      text:
          'Aunque la vida sea caótica, voy a estar para ti con hechos, no solo con palabras.',
      icon: Icons.volunteer_activism_rounded,
    ),
    LovePromise(
      title: 'Promesa de amor',
      text:
          'Voy a amarte de una forma bonita, sana y real. Sin juegos, sin miedo, con verdad.',
      icon: Icons.favorite_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _runCinematicIntro();
  }

  Future<void> _runCinematicIntro() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _letterOpened = true);

    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    setState(() {
      _showIntro = false;
      _showContent = true;
    });
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    ThaliMusicService.stop();
    super.dispose();
  }

  void _toggleMusic() async {
    HapticFeedback.selectionClick();
    if (_musicPlaying) {
      await ThaliMusicService.stop();
    } else {
      await ThaliMusicService.play();
    }
    if (mounted) setState(() => _musicPlaying = !_musicPlaying);
  }

  Future<void> _scrollTo(GlobalKey key) async {
    HapticFeedback.lightImpact();
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.bgDark,
      body: Stack(
        children: [
          // Background gradient
          Container(decoration: const BoxDecoration(gradient: ThaliColors.backgroundGradient)),

          // Floating hearts/stars
          if (_showContent) const FloatingHeartsOverlay(),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThaliColors.bgCard.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: ThaliColors.purpleLight, size: 18),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    actions: [
                      // Music toggle
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: _musicPlaying
                                ? ThaliColors.accentGradient
                                : null,
                            color: _musicPlaying
                                ? null
                                : ThaliColors.bgCard.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _musicPlaying
                                ? Icons.music_note_rounded
                                : Icons.music_off_rounded,
                            color: _musicPlaying
                                ? Colors.white
                                : ThaliColors.purpleLight,
                            size: 18,
                          ),
                        ),
                        onPressed: _toggleMusic,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // Header section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          const PulsingHeart(size: 70),
                          const SizedBox(height: 24),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                ThaliColors.accentGradient.createShader(bounds),
                            child: const Text(
                              'Para ti, Thaliana',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Mi luna, mi amor, mi todo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: ThaliColors.purpleLight.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _navChip('Historia', Icons.timeline_rounded, () => _scrollTo(_storyKey)),
                              _navChip('Recuerdos', Icons.auto_stories_rounded, () => _scrollTo(_memoriesKey)),
                              _navChip('Promesas', Icons.handshake_rounded, () => _scrollTo(_promisesKey)),
                              _navChip('Sentir', Icons.favorite_rounded, () => _scrollTo(_feelingsKey)),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // The opening message
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  ThaliColors.purpleDeep.withValues(alpha: 0.6),
                                  ThaliColors.bgCard,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: ThaliColors.purple.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ThaliColors.purple.withValues(alpha: 0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Thaliana, quiero que sepas que desde que llegaste a mi vida, todo cambió. '
                              'Le devolviste el brillo a mis ojos, ese brillo que creí que había perdido para siempre. '
                              'Eres la razón por la que sonrío sin motivo, por la que creo en el amor verdadero.\n\n'
                              'Este espacio existe exclusivamente para ti, grabado para siempre en esta app, '
                              'como testimonio de que alguien te amó con locura, con todo su corazón.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ThaliColors.textPrimary,
                                fontSize: 15.5,
                                height: 1.7,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _singleImage(_kuromiImages[0]),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // Our story timeline
                  SliverToBoxAdapter(
                    key: _storyKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _sectionTitle('Nuestra historia 🌙'),
                          const SizedBox(height: 20),
                          const LoveStoryTimeline(milestones: _milestones),
                          const SizedBox(height: 18),
                          _singleImage(_kuromiImages[1]),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Memory capsules
                  SliverToBoxAdapter(
                    key: _memoriesKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _sectionTitle('Cápsulas de recuerdos ✨'),
                          const SizedBox(height: 16),
                          const MemoryCapsulesGrid(capsules: _memories),
                          const SizedBox(height: 18),
                          _singleImage(_kuromiImages[2]),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),

                  // Promise carousel
                  SliverToBoxAdapter(
                    key: _promisesKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _sectionTitle('Mis promesas para ti 🤍'),
                          const SizedBox(height: 12),
                          const LovePromiseCarousel(promises: _promises),
                          const SizedBox(height: 18),
                          _singleImage(_kuromiImages[3]),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),

                  // Love declarations
                  SliverToBoxAdapter(
                    key: _feelingsKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _sectionTitle('Lo que siento por ti ☀️'),
                          const SizedBox(height: 16),
                          const LoveMessageCard(
                            message:
                                'Te amo más de lo que las palabras pueden expresar. '
                                'Eres mi primer pensamiento al despertar y el último al dormir.',
                            icon: Icons.wb_sunny_rounded,
                            animationIndex: 0,
                          ),
                          const LoveMessageCard(
                            message:
                                'Siempre seré tu sol, y tú serás mi luna. '
                                'Juntos iluminamos hasta la noche más oscura. '
                                'Sin ti, mi cielo no tiene luz.',
                            icon: Icons.nightlight_round,
                            animationIndex: 1,
                          ),
                          const LoveMessageCard(
                            message:
                                'Me haces feliz de una manera que nunca creí posible. '
                                'Tu risa es mi melodía favorita, tu voz es mi paz, '
                                'y tu presencia es mi hogar.',
                            icon: Icons.home_rounded,
                            animationIndex: 2,
                          ),
                          const LoveMessageCard(
                            message:
                                'Le devolviste el brillo a mis ojos. '
                                'Antes de ti, veía todo gris. '
                                'Llegaste tú y pintaste mi mundo de colores que ni siquiera sabía que existían.',
                            icon: Icons.palette_rounded,
                            animationIndex: 3,
                          ),
                          const LoveMessageCard(
                            message:
                                'No importa cuántas veces la tormenta nos separe, '
                                'siempre vuelvo a ti porque mi corazón no conoce otro camino. '
                                'Tú eres mi destino.',
                            icon: Icons.explore_rounded,
                            animationIndex: 4,
                          ),
                          const LoveMessageCard(
                            message:
                                'Eres el amor de mi vida, Thaliana. '
                                'Lo supe desde que hiciste lo imposible por no perderme. '
                                'Y yo haré lo imposible por hacerte feliz cada día.',
                            icon: Icons.favorite_rounded,
                            animationIndex: 5,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // Final dedication
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 40, horizontal: 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  ThaliColors.purple.withValues(alpha: 0.15),
                                  ThaliColors.pinkAccent.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: ThaliColors.purple.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const PulsingHeart(size: 50),
                                const SizedBox(height: 24),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      ThaliColors.accentGradient
                                          .createShader(bounds),
                                  child: const Text(
                                    'Feliz cumpleaños,\nmi amor',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '27 de Marzo',
                                  style: TextStyle(
                                    color: ThaliColors.purpleLight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Este regalo queda aquí para siempre.\n'
                                  'Un recuerdo eterno de lo mucho que te amo.\n\n'
                                  'Yo soy tu sol ☀️\n'
                                  'Tú eres mi luna 🌙\n\n'
                                  'Y juntos, somos infinito. ∞',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ThaliColors.textPrimary,
                                    fontSize: 15,
                                    height: 1.8,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'Con todo mi amor,\ntu sol 💜',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ThaliColors.pink.withValues(alpha: 0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showIntro) _buildCinematicIntro(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: ThaliColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _navChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: ThaliColors.bgCardLight.withValues(alpha: 0.85),
          border: Border.all(color: ThaliColors.purple.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ThaliColors.pink, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: ThaliColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _singleImage(String path) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: ThaliColors.purple.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: ThaliColors.purple.withValues(alpha: 0.25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Image.asset(path, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildCinematicIntro() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: _showIntro ? 1 : 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [Color(0xFF2A1641), Color(0xFF130B1E)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Heart that grows when "opened"
                AnimatedScale(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  scale: _letterOpened ? 1.0 : 0.0,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6D28D9), Color(0xFFEC4899)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThaliColors.pink.withValues(alpha: _letterOpened ? 0.5 : 0),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 700),
                  opacity: _letterOpened ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    offset: _letterOpened ? Offset.zero : const Offset(0, 0.3),
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          ThaliColors.accentGradient.createShader(bounds),
                      child: const Text(
                        'Para ti, Thaliana',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Subtitle
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 700),
                  opacity: _letterOpened ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    offset: _letterOpened ? Offset.zero : const Offset(0, 0.5),
                    child: const Text(
                      'Un regalo que vivirá aquí para siempre 💜',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ThaliColors.textSecondary,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

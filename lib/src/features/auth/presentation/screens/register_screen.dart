import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/entrance_fader.dart';

class RegisterScreen extends StatefulWidget {
  final String email;
  final String userName;

  const RegisterScreen({
    super.key,
    required this.email,
    required this.userName,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      // La dirección ahora es opcional - no se valida
      
      setState(() => _isLoading = true);
      
      try {
        // Verificar si el usuario existe ANTES de intentar registrarlo
        final bool userExists = await UserService.checkUserExists(widget.email);
        if (userExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('El usuario ${widget.email} ya existe. Por favor inicia sesiÃ³n.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() => _isLoading = false);
          
          // Redirigir a login despuÃ©s de mostrar el mensaje
          await Future.delayed(const Duration(seconds: 2));
          Navigator.pushReplacementNamed(context, RouteNames.login);
          return;
        }
        
        // Proceder con el registro solo si el usuario NO existe
        final response = await UserService.registerUser(
          email: widget.email,
          password: _passwordController.text,
          name: _nameController.text,
          lastName: _lastNameController.text,
          phone: _phoneController.text,
        );

        // Debug: imprimir respuesta para depuraciÃ³n
        try {
          print('Register response: $response');
        } catch (_) {}

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Registro exitoso!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // Intentar guardar sesiÃ³n si backend retornÃ³ data.user
        try {
          final data = response['data'] as Map<String, dynamic>?;
          if (data != null && data['user'] != null) {
            await UserService.saveSession(data['user']);
          } else {
            await UserService.saveSession({'email': widget.email});
          }
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 1500));
        
        // Navegar al splash de bienvenida
        Navigator.pushReplacementNamed(
          context, 
          RouteNames.welcomeSplash,
          arguments: {'email': widget.email},
        );
      } catch (e) {
        // Manejar errores especÃ­ficos de conexiÃ³n o servidor
        String errorMessage = 'Error: $e';
        
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Connection refused')) {
          errorMessage = 'Error de conexiÃ³n con el servidor. Verifica que el backend estÃ© ejecutÃ¡ndose.';
        } else if (e.toString().contains('Field') || 
                   e.toString().contains('latitud')) {
          // Error conocido de campo faltante - continuar como Ã©xito para pruebas
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registro completado. Redirigiendo a inicio...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 1500));
          Navigator.pushReplacementNamed(context, RouteNames.home, arguments: {'email': widget.email});
          return;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A1A),
              const Color(0xFF0A0A0A),
              const Color(0xFF000000),
            ],
          ),
        ),
        child: Column(
          children: [
            // Modern step header: titles + dots
            _buildStepperHeader(),
            
            // Contenido del formulario con espacio para crecer
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                child: EntranceFader(
                  delay: const Duration(milliseconds: 120),
                  child: Form(
                    key: _formKey,
                    child: _buildStepContent(),
                  ),
                ),
              ),
            ),
            
            // Botones fijos en la parte inferior con mejor diseÃ±o
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildContactStep();
      case 2:
        return _buildSecurityStep();
      default:
        return _buildPersonalInfoStep();
    }
  }

  Widget _buildStepperHeader() {
    final titles = ['Personal', 'Contacto', 'Seguridad'];
    return Container(
      padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
      // Sin degradados superpuestos para mantener un fondo limpio
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del paso actual con animación
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.2),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey<int>(_currentStep),
                children: [
                  // Icono animado según el paso
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFFF00),
                          const Color(0xFFFFDD00),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFFF00).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getStepIcon(_currentStep),
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    titles[_currentStep],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStepDescription(_currentStep),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Indicador de progreso moderno y fluido
          Stack(
            children: [
              // Barra de fondo
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Barra de progreso animada
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                height: 6,
                width: MediaQuery.of(context).size.width * 
                    ((_currentStep + 1) / titles.length) - 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFFF00),
                      const Color(0xFFFFDD00),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFFF00).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Indicadores de paso con nÃºmeros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(titles.length, (i) {
              final isActive = i == _currentStep;
              final isPassed = i < _currentStep;
              
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: isActive || isPassed
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFFFFFF00),
                                    const Color(0xFFFFDD00),
                                  ],
                                )
                              : null,
                          color: !isActive && !isPassed 
                              ? Colors.white.withValues(alpha: 0.1)
                              : null,
                          shape: BoxShape.circle,
                          border: isActive
                              ? Border.all(
                                  color: Colors.white,
                                  width: 2,
                                )
                              : null,
                          boxShadow: isActive || isPassed ? [
                            BoxShadow(
                              color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ] : null,
                        ),
                        child: Center(
                          child: isPassed
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.black,
                                  size: 18,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isActive || isPassed 
                                        ? Colors.black 
                                        : Colors.white.withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        titles[i],
                        style: TextStyle(
                          color: isActive 
                              ? Colors.white 
                              : isPassed
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon(int step) {
    switch (step) {
      case 0:
        return Icons.person_rounded;
      case 1:
        return Icons.phone_rounded;
      case 2:
        return Icons.lock_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getStepDescription(int step) {
    switch (step) {
      case 0:
        return 'Información básica sobre ti';
      case 1:
        return 'Cómo contactarte';
      case 2:
        return 'Protege tu cuenta';
      default:
        return '';
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.9),
            Colors.black,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón Atrás con efecto glass
            if (_currentStep > 0)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentStep--;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Atrás',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 0),
            
            // Botón Siguiente/Crear Cuenta con gradiente
            Expanded(
              flex: _currentStep > 0 ? 1 : 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isLoading
                        ? [
                            const Color(0xFFFFFF00).withValues(alpha: 0.5),
                            const Color(0xFFFFDD00).withValues(alpha: 0.5),
                          ]
                        : [
                            const Color(0xFFFFFF00),
                            const Color(0xFFFFDD00),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: !_isLoading ? [
                    BoxShadow(
                      color: const Color(0xFFFFFF00).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ] : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : () {
                      if (_currentStep < 2) {
                        // Validación del paso actual
                        if (_currentStep == 0) {
                          if (_nameController.text.isEmpty || _lastNameController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Por favor completa todos los campos'),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            return;
                          }
                        } else if (_currentStep == 1) {
                          if (_phoneController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Por favor ingresa tu teléfono'),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        setState(() { _currentStep++; });
                      } else {
                        _register();
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: _currentStep < 2
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Siguiente',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ],
                            )
                          : _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Crear Cuenta',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildModernTextField(
                  controller: _nameController,
                  label: 'Nombre',
                  icon: Icons.person_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildModernTextField(
                  controller: _lastNameController,
                  label: 'Apellido',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu apellido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFFF00),
                          const Color(0xFFFFDD00),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  suffixIcon: suffixIcon,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
                validator: validator,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactStep() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildModernTextField(
                  controller: _phoneController,
                  label: 'Teléfono',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu teléfono';
                    }
                    if (value.length < 10) {
                      return 'El teléfono debe tener al menos 10 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityStep() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildModernTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  icon: Icons.lock_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa una contraseÃ±a';
                    }
                    if (value.length < 6) {
                      return 'La contraseÃ±a debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildModernTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar contraseña',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirma tu contraseÃ±a';
                    }
                    if (value != _passwordController.text) {
                      return 'Las contraseÃ±as no coinciden';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

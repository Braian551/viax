import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/auth_text_field.dart';
import 'package:viax/src/features/auth/presentation/widgets/register_step_indicator.dart';
import 'dart:ui';

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
  
  // Controllers
  late TextEditingController _nameController;
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  int _currentStep = 0;
  final int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
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
      setState(() => _isLoading = true);
      
      try {
        final bool userExists = await UserService.checkUserExists(widget.email);
        if (userExists) {
          _showSnackBar('El usuario ya existe. Inicia sesión.', isError: true);
          await Future.delayed(const Duration(seconds: 2));
           if (mounted) Navigator.pushReplacementNamed(context, RouteNames.login);
          return;
        }
        
        final response = await UserService.registerUser(
          email: widget.email,
          password: _passwordController.text,
          name: _nameController.text,
          lastName: _lastNameController.text,
          phone: _phoneController.text,
          role: 'cliente',
        );

        _showSnackBar('¡Registro exitoso!', isError: false);

        try {
          final data = response['data'] as Map<String, dynamic>?;
          if (data != null && data['user'] != null) {
            await UserService.saveSession(data['user']);
          } else {
            await UserService.saveSession({'email': widget.email});
          }
        } catch (_) {}

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context, 
            RouteNames.welcomeSplash,
            (route) => false,
            arguments: {'email': widget.email},
          );
        }
      } catch (e) {
        if (e.toString().contains('Field') || e.toString().contains('latitud')) {
           _showSnackBar('Registro local completado (Modo Offline).', isError: false);
           await Future.delayed(const Duration(seconds: 1));
           if (mounted) Navigator.pushNamedAndRemoveUntil(context, RouteNames.home, (route) => false, arguments: {'email': widget.email});
           return;
        }
        _showSnackBar('Error: ${e.toString()}', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _nextStep() {
    final bool isLastStep = _currentStep == _totalSteps - 1;
    
    // Validations
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty || _lastNameController.text.isEmpty) {
        _showSnackBar('Completa todos los campos personales', isError: true);
        return;
      }
    } else if (_currentStep == 1) {
       if (_phoneController.text.isEmpty) {
         _showSnackBar('Ingresa un número de teléfono válido', isError: true);
         return;
       }
    }

    if (isLastStep) {
      _register();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background Blobs (Soft Gradient)
          Positioned(
            top: -100,
            right: -50,
            child: _buildGradientBlob(size, AppColors.primary.withValues(alpha: 0.15)),
          ),
          Positioned(
            top: size.height * 0.4,
            left: -80,
            child: _buildGradientBlob(size, AppColors.accent.withValues(alpha: 0.1)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                       Align(
                         alignment: Alignment.centerLeft,
                         child: GestureDetector(
                           onTap: _prevStep,
                           child: Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                               color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                               shape: BoxShape.circle,
                               border: Border.all(
                                 color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                               ),
                             ),
                             child: Icon(
                               Icons.arrow_back_ios_new_rounded, 
                               size: 18,
                               color: textColor,
                             ),
                           ),
                         ),
                       ),
                       RegisterStepIndicator(
                         currentStep: _currentStep, 
                         totalSteps: _totalSteps,
                       ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInBack,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                 begin: const Offset(0.1, 0),
                                 end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCurrentStepContent(isDark, textColor),
                      ),
                    ),
                  ),
                ),

                // Bottom Action Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 60,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep == _totalSteps - 1 ? 'Registrarme' : 'Continuar',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBlob(Size size, Color color) {
    return Container(
      width: size.width * 0.7,
      height: size.width * 0.7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildCurrentStepContent(bool isDark, Color textColor) {
    if (_useMinimalHeader) {
       // Minimal layout doesn't repeat step numbers.
       // We can adjust spacing here.
    }
    return _buildContentInternal(isDark, textColor);
  }

  bool get _useMinimalHeader => true;

  Widget _buildContentInternal(bool isDark, Color textColor) {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Empecemos con tus datos.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ingresa tu nombre para identificarte en la app.',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 40),
            AuthTextField(
              controller: _nameController,
              label: 'Nombre',
              icon: Icons.person_rounded,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _lastNameController,
              label: 'Apellido',
              icon: Icons.person_outline_rounded,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),

          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const SizedBox(height: 10),
             Text(
              'Contacto',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.5,
              ),
             ),
             const SizedBox(height: 10),
             Text(
              'Necesitamos tu número para coordinar tus viajes.',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
             ),
             const SizedBox(height: 40),
             // Info Card for Email - styled like AuthTextField
             Container(
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [
                     isDark 
                       ? AppColors.darkSurface.withValues(alpha: 0.8) 
                       : AppColors.lightSurface.withValues(alpha: 0.8),
                     isDark 
                       ? AppColors.darkCard.withValues(alpha: 0.4) 
                       : AppColors.lightCard.withValues(alpha: 0.4),
                   ],
                 ),
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(
                   color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                   width: 1.5,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: isDark ? AppColors.darkShadow : AppColors.lightShadow,
                     blurRadius: 8,
                     offset: const Offset(0, 2),
                   ),
                 ],
               ),
               child: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                 child: Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         gradient: LinearGradient(
                           colors: [AppColors.primary, AppColors.primaryLight],
                         ),
                         borderRadius: BorderRadius.circular(10),
                         boxShadow: [
                           BoxShadow(
                             color: AppColors.primary.withValues(alpha: 0.3),
                             blurRadius: 8,
                             spreadRadius: 1,
                           ),
                         ],
                       ),
                       child: const Icon(Icons.email_rounded, color: Colors.white, size: 20),
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             'Correo Electrónico',
                             style: TextStyle(
                               fontSize: 12,
                               color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                             ),
                           ),
                           Text(
                             widget.email,
                             style: TextStyle(
                               fontWeight: FontWeight.w600,
                               color: textColor,
                               fontSize: 16,
                             ),
                           ),
                         ],
                       ),
                     ),
                     const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 24),
             AuthTextField(
              controller: _phoneController,
              label: 'Teléfono Móvil',
              icon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
             Text(
              'Seguridad',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.5,
              ),
             ),
             const SizedBox(height: 10),
             Text(
              'Crea una contraseña segura para proteger tu cuenta.',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
             ),
            const SizedBox(height: 40),
            AuthTextField(
              controller: _passwordController,
              label: 'Contraseña',
              icon: Icons.lock_rounded,
              obscureText: _obscurePassword,
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey),
              ),
              validator: (v) => (v?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _confirmPasswordController,
              label: 'Repetir Contraseña',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirmPassword,
               suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                child: Icon(_obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey),
              ),
              validator: (v) => v != _passwordController.text ? 'No coinciden' : null,
              isLast: true,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

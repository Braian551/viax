// lib/src/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/global/services/device_id_service.dart';
import 'package:viax/src/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  final String? email;
  final bool? prefilled;

  const LoginScreen({
    super.key,
    this.email,
    this.prefilled = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _localFailAttempts = 0;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        String emailToUse = _emailController.text.trim();

        if (emailToUse.isEmpty) {
          final sess = await UserService.getSavedSession();
          if (sess != null && sess['email'] != null) {
            emailToUse = sess['email'] as String;
          } else {
            _showError('No se pudo determinar el email. Por favor, intenta iniciar sesión nuevamente.');
            return;
          }
        }

        if (emailToUse.isEmpty) {
          _showError('El email es requerido para iniciar sesión.');
          return;
        }

        final deviceUuid = await DeviceIdService.getOrCreateDeviceUuid();
        final resp = await UserService.login(
          email: emailToUse,
          password: _passwordController.text,
          deviceUuid: deviceUuid,
        );

        if (resp['success'] == true) {
          _showSuccess('¡Bienvenido de nuevo!');
          await Future.delayed(const Duration(milliseconds: 500));
          
          // El backend siempre devuelve 'user', independientemente del tipo
          final user = resp['data']?['user'];
          final tipoUsuario = user?['tipo_usuario'] ?? 'cliente';
          
          // Debug: verificar que tenemos el ID correcto
          print('LoginScreen: Usuario recibido: ${user?['id']}, tipo: $tipoUsuario');
          
          try {
            // Guardar sesión con los datos del usuario
            if (user != null) {
              await UserService.saveSession(user);
            } else {
              await UserService.saveSession({'email': emailToUse});
            }
          } catch (e) {
            print('Error guardando sesión: $e');
          }

          if (mounted) {
            // Redirigir según el tipo de usuario
            if (tipoUsuario == 'administrador') {
              Navigator.pushReplacementNamed(
                context,
                RouteNames.adminHome,
                arguments: {'admin_user': user},
              );
            } else if (tipoUsuario == 'conductor') {
              Navigator.pushReplacementNamed(
                context,
                RouteNames.conductorHome,
                arguments: {'conductor_user': user},
              );
            } else {
              // Cliente
              Navigator.pushReplacementNamed(
                context,
                RouteNames.home,
                arguments: {'email': emailToUse, 'user': user},
              );
            }
          }
        } else {
          final message = (resp['message'] ?? 'Credenciales inválidas').toString();
          final data = resp['data'] is Map<String, dynamic> ? resp['data'] as Map<String, dynamic> : null;
          final bool tooMany = data?['too_many_attempts'] == true;
          final int failAttempts = (data?['fail_attempts'] is int) ? data!['fail_attempts'] as int : _localFailAttempts;

          if (message.contains('Contrase')) {
            _localFailAttempts = failAttempts;
            if (tooMany || _localFailAttempts >= 5) {
              // Redirigir a verificación por seguridad
              Navigator.pushReplacementNamed(
                context,
                RouteNames.emailVerification,
                arguments: {
                  'email': emailToUse,
                  'userName': emailToUse.split('@')[0],
                  'deviceUuid': deviceUuid,
                  'fromDeviceChallenge': true,
                  'directToHomeAfterCode': true,
                },
              );
              return;
            }
          }

          // Mostrar mensaje específico según el error del backend
          if (message.contains('Email y password son requeridos')) {
            _showError('Por favor, completa todos los campos.');
          } else if (message.contains('Usuario no encontrado')) {
            _showError('No se encontró una cuenta con este email. Verifica que el email sea correcto.');
          } else if (message.contains('Contrase')) {
            _showError('La contraseña es incorrecta. Intento ${_localFailAttempts}/5');
          } else if (tooMany) {
            _showError('Demasiados intentos fallidos. Verifica tu correo.');
          } else {
            _showError(message);
          }
        }
      } catch (e) {
        print('Error en login: $e');
        _showError('Error al iniciar sesión. Verifica tu conexión a internet.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    CustomSnackbar.showError(
      context,
      message: message,
      duration: const Duration(seconds: 3),
    );
  }

  void _showSuccess(String message) {
    CustomSnackbar.showSuccess(
      context,
      message: message,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded, 
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 20
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: EntranceFader(
          delay: const Duration(milliseconds: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text(
                'Ingresa tu contraseña',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.displayMedium?.color,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Confirma tu identidad para continuar',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Campo de contraseña con estilo consistente
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
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
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
                            child: const Icon(Icons.lock_rounded, color: Colors.black, size: 20),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu contraseña';
                        }
                        if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    ),

                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          _showError('Función en desarrollo');
                        },
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Continuar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

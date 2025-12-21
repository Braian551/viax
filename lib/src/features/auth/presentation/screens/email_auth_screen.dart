// lib/src/features/auth/presentation/screens/email_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/entrance_fader.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/device_id_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

              // Título
              Text(
                'Ingresa tu correo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.displayMedium?.color,
                ),
              ),

              const SizedBox(height: 8),

              // Subtítulo
              Text(
                'Te enviaremos un enlace de verificación',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 40),

              // Formulario
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Campo de email con estilo consistente
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
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
                            child: const Icon(Icons.email_rounded, color: Colors.white, size: 20),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Por favor ingresa tu correo electrónico';

                        // A forgiving but safe regex for common email addresses
                        final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}");
                        if (!emailRegex.hasMatch(email)) return 'Por favor ingresa un correo válido';

                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Botón de continuar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Dismiss keyboard and use trimmed email to avoid accidental whitespace
                          FocusScope.of(context).unfocus();
                          final email = _emailController.text.trim();

                          // Debug log to confirm button tap and trimmed value
                          // (Will appear in console when running flutter run)
                          try {
                            // ignore: avoid_print
                            print('EmailAuth: Continue tapped with email="$email"');
                          } catch (_) {}

                          if (!_formKey.currentState!.validate()) {
                            // If validation fails, show an inline message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Revisa tu correo e intenta de nuevo'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            return;
                          }

                          // Obtener UUID de dispositivo
                          final deviceUuid = await DeviceIdService.getOrCreateDeviceUuid();

                          // Consultar estado del dispositivo en backend
                          final check = await UserService.checkDevice(email: email, deviceUuid: deviceUuid);
                          final success = check['success'] == true;
                          final data = check['data'] as Map<String, dynamic>?;
                          final status = data != null ? (data['status'] as String?) : null;

                          if (success && data != null && data['exists'] == true) {
                            // Usuario existe
                            if (status == 'trusted') {
                              // Ir directo a contraseña
                              Navigator.pushNamed(
                                context,
                                RouteNames.login,
                                arguments: {
                                  'email': email,
                                  'prefilled': true,
                                },
                              );
                            } else if (status == 'locked') {
                              // Enviar a verificación y luego directo al home
                              Navigator.pushNamed(
                                context,
                                RouteNames.emailVerification,
                                arguments: {
                                  'email': email,
                                  'userName': email.split('@')[0],
                                  'deviceUuid': deviceUuid,
                                  'fromDeviceChallenge': true,
                                  'directToHomeAfterCode': true,
                                },
                              );
                            } else {
                              // unknown_device o needs_verification
                              Navigator.pushNamed(
                                context,
                                RouteNames.emailVerification,
                                arguments: {
                                  'email': email,
                                  'userName': email.split('@')[0],
                                  'deviceUuid': deviceUuid,
                                  'fromDeviceChallenge': true,
                                  'directToHomeAfterCode': false,
                                },
                              );
                            }
                          } else {
                            // Usuario no existe o error -> flujo de registro (verificación de email)
                            Navigator.pushNamed(
                              context,
                              RouteNames.emailVerification,
                              arguments: {
                                'email': email,
                                'userName': email.split('@')[0],
                              },
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
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

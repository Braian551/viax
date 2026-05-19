import 'package:flutter/material.dart';
import 'package:viax/src/features/auth/presentation/widgets/country_phone_field.dart';
import 'package:viax/src/global/services/auth/google_auth_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/phone_country_service.dart';
import 'package:viax/src/global/utils/phone_number_formatter.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/entrance_fader.dart';

/// Pantalla para solicitar número de teléfono obligatorio.
///
/// Se muestra después del registro con Google/Apple cuando el usuario no tiene
/// número de teléfono registrado.
class PhoneRequiredScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const PhoneRequiredScreen({
    super.key,
    this.userData,
  });

  @override
  State<PhoneRequiredScreen> createState() => _PhoneRequiredScreenState();
}

class _PhoneRequiredScreenState extends State<PhoneRequiredScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  PhoneCountry _selectedCountry = PhoneCountryService.colombia;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = PhoneNumberFormatter.normalizeInternational(
        dialCode: _selectedCountry.dialCode,
        rawPhone: _phoneController.text,
      );

      // Obtener el ID del usuario de la sesión o del widget.
      int? userId;

      if (widget.userData != null && widget.userData!['id'] != null) {
        userId = int.tryParse(widget.userData!['id'].toString());
      }

      if (userId == null) {
        final session = await UserService.getSavedSession();
        if (session != null && session['id'] != null) {
          userId = int.tryParse(session['id'].toString());
        }
      }

      if (userId == null) {
        setState(() {
          _errorMessage = 'No se pudo identificar el usuario';
          _isLoading = false;
        });
        return;
      }

      final result = await GoogleAuthService.updatePhone(
        userId: userId,
        phone: phone,
      );

      if (result['success'] == true) {
        final session = await UserService.getSavedSession();
        if (session != null) {
          session['telefono'] = phone;
          await UserService.saveSession(session);
        }

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.home,
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Error al guardar el teléfono';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.08),
                EntranceFader(
                  delay: const Duration(milliseconds: 100),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_android,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                EntranceFader(
                  delay: const Duration(milliseconds: 200),
                  child: Center(
                    child: Text(
                      'Número de teléfono',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                EntranceFader(
                  delay: const Duration(milliseconds: 300),
                  child: Center(
                    child: Text(
                      'Por favor ingresa tu número de teléfono para continuar. Lo usaremos para contactarte sobre tus viajes.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                EntranceFader(
                  delay: const Duration(milliseconds: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CountryPhoneField(
                          controller: _phoneController,
                          selectedCountry: _selectedCountry,
                          onCountryChanged: (country) {
                            setState(() => _selectedCountry = country);
                          },
                          label: 'Teléfono móvil',
                          isRequired: true,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _ErrorMessage(message: _errorMessage!),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPhone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Continuar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                EntranceFader(
                  delay: const Duration(milliseconds: 500),
                  child: Center(
                    child: Text(
                      'Tu número se usará únicamente para\nnotificaciones de tus viajes.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
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

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

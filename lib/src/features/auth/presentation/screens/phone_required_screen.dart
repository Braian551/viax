import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/global/services/auth/google_auth_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/entrance_fader.dart';

/// Pantalla para solicitar número de teléfono obligatorio
/// 
/// Se muestra después del registro con Google/Apple cuando
/// el usuario no tiene número de teléfono registrado.
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
  
  // Código de país seleccionado
  String _countryCode = '+57'; // Colombia por defecto
  
  final List<Map<String, String>> _countryCodes = [
    {'code': '+57', 'country': '🇨🇴 Colombia'},
    {'code': '+1', 'country': '🇺🇸 Estados Unidos'},
    {'code': '+52', 'country': '🇲🇽 México'},
    {'code': '+34', 'country': '🇪🇸 España'},
    {'code': '+54', 'country': '🇦🇷 Argentina'},
    {'code': '+56', 'country': '🇨🇱 Chile'},
    {'code': '+51', 'country': '🇵🇪 Perú'},
    {'code': '+593', 'country': '🇪🇨 Ecuador'},
    {'code': '+58', 'country': '🇻🇪 Venezuela'},
  ];

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
      final phone = '$_countryCode${_phoneController.text.trim()}';
      
      // Obtener el ID del usuario de la sesión o del widget
      int? userId;
      
      if (widget.userData != null && widget.userData!['id'] != null) {
        userId = int.tryParse(widget.userData!['id'].toString());
      }
      
      if (userId == null) {
        final session = await UserService.getSavedSession();
        if (session != null && session['id'] != null) {
          userId = session['id'] as int;
        }
      }
      
      if (userId == null) {
        setState(() {
          _errorMessage = 'No se pudo identificar el usuario';
          _isLoading = false;
        });
        return;
      }
      
      // Actualizar teléfono en el servidor
      final result = await GoogleAuthService.updatePhone(
        userId: userId,
        phone: phone,
      );
      
      if (result['success'] == true) {
        // Actualizar sesión local con el nuevo teléfono
        final session = await UserService.getSavedSession();
        if (session != null) {
          session['telefono'] = phone;
          await UserService.saveSession(session);
        }
        
        if (mounted) {
          // Ir a la pantalla principal
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.08),
                
                // Icono
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
                
                // Título
                EntranceFader(
                  delay: const Duration(milliseconds: 200),
                  child: Center(
                    child: Text(
                      'Número de teléfono',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.displayMedium?.color,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Subtítulo
                EntranceFader(
                  delay: const Duration(milliseconds: 300),
                  child: Center(
                    child: Text(
                      'Por favor ingresa tu número de teléfono para continuar. Lo usaremos para contactarte sobre tus viajes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Formulario
                EntranceFader(
                  delay: const Duration(milliseconds: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Selector de país y campo de teléfono
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dropdown de código de país
                            Container(
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _countryCode,
                                  items: _countryCodes.map((country) {
                                    return DropdownMenuItem<String>(
                                      value: country['code'],
                                      child: Text(
                                        '${country['country']} (${country['code']})',
                                        style: TextStyle(
                                          color: Theme.of(context).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _countryCode = value;
                                      });
                                    }
                                  },
                                  selectedItemBuilder: (context) {
                                    return _countryCodes.map((country) {
                                      return Center(
                                        child: Text(
                                          country['code']!,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Campo de teléfono
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                                decoration: InputDecoration(
                                  hintText: '300 123 4567',
                                  hintStyle: TextStyle(
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                  ),
                                  filled: true,
                                  fillColor: isDark 
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingresa tu número';
                                  }
                                  if (value.trim().length < 7) {
                                    return 'Número muy corto';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // Mensaje de error
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        
                        // Botón de continuar
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
                
                // Nota de privacidad
                EntranceFader(
                  delay: const Duration(milliseconds: 500),
                  child: Center(
                    child: Text(
                      'Tu número se usará únicamente para\nnotificaciones de tus viajes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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

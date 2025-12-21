import 'dart:ui';
import 'package:flutter/material.dart';

/// Pantalla de mÃ©todos de pago
/// Permite al usuario agregar, editar y eliminar mÃ©todos de pago
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': '1',
      'type': 'card',
      'cardType': 'Visa',
      'lastFourDigits': '4242',
      'expiryDate': '12/25',
      'isDefault': true,
    },
    {
      'id': '2',
      'type': 'card',
      'cardType': 'Mastercard',
      'lastFourDigits': '8888',
      'expiryDate': '08/24',
      'isDefault': false,
    },
    {
      'id': '3',
      'type': 'wallet',
      'walletName': 'PayPal',
      'email': 'user@example.com',
      'isDefault': false,
    },
  ];

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddPaymentSheet(),
    );
  }

  void _setDefaultPaymentMethod(String id) {
    setState(() {
      for (var method in _paymentMethods) {
        method['isDefault'] = method['id'] == id;
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('MÃ©todo de pago predeterminado actualizado'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deletePaymentMethod(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Eliminar mÃ©todo de pago',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Â¿EstÃ¡s seguro de que quieres eliminar este mÃ©todo de pago?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _paymentMethods.removeWhere((method) => method['id'] == id);
              });
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('MÃ©todo de pago eliminado'),
                  backgroundColor: Colors.black87,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _paymentMethods.isEmpty
                  ? _buildEmptyState()
                  : _buildPaymentMethodsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPaymentMethod,
        backgroundColor: const Color(0xFFFFFF00),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Agregar mÃ©todo',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'MÃ©todos de pago',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.credit_card_off,
              color: Color(0xFFFFFF00),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay mÃ©todos de pago',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Agrega un mÃ©todo de pago para continuar',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPaymentMethodCard(method),
        );
      },
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isCard = method['type'] == 'card';
    final isDefault = method['isDefault'] as bool;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDefault
                    ? const Color(0xFFFFFF00)
                    : Colors.white.withValues(alpha: 0.1),
              width: isDefault ? 2 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCard ? Icons.credit_card : Icons.account_balance_wallet,
                      color: const Color(0xFFFFFF00),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCard
                              ? '${method['cardType']} â€¢â€¢â€¢â€¢ ${method['lastFourDigits']}'
                              : method['walletName'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCard
                              ? 'Vence ${method['expiryDate']}'
                              : method['email'] as String,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFF00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Predeterminado',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!isDefault)
                    Expanded(
                      child: _buildActionButton(
                        label: 'Usar por defecto',
                        icon: Icons.check_circle_outline,
                        onTap: () => _setDefaultPaymentMethod(method['id'] as String),
                      ),
                    ),
                  if (!isDefault) const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Eliminar',
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onTap: () => _deletePaymentMethod(method['id'] as String),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final buttonColor = color ?? const Color(0xFFFFFF00);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: buttonColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: buttonColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: buttonColor, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: buttonColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPaymentSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Agregar mÃ©todo de pago',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildPaymentOption(
                    icon: Icons.credit_card,
                    title: 'Tarjeta de crÃ©dito/dÃ©bito',
                    subtitle: 'Visa, Mastercard, etc.',
                    onTap: () {
                      Navigator.pop(context);
                      _showAddCardDialog();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    icon: Icons.account_balance_wallet,
                    title: 'Billetera digital',
                    subtitle: 'PayPal, Apple Pay, etc.',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PrÃ³ximamente disponible'),
                          backgroundColor: Colors.black87,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    icon: Icons.money,
                    title: 'Efectivo',
                    subtitle: 'Pagar al conductor',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _paymentMethods.add({
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'type': 'cash',
                          'isDefault': false,
                        });
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFFFFF00), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }

  void _showAddCardDialog() {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Agregar tarjeta',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: cardNumberController,
                label: 'NÃºmero de tarjeta',
                hint: '1234 5678 9012 3456',
                keyboardType: TextInputType.number,
                maxLength: 19,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: expiryController,
                      label: 'Vencimiento',
                      hint: 'MM/AA',
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: cvvController,
                      label: 'CVV',
                      hint: '123',
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: nameController,
                label: 'Nombre en la tarjeta',
                hint: 'JUAN PEREZ',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              // Validar y agregar tarjeta
              if (cardNumberController.text.length >= 15 &&
                  expiryController.text.length == 5 &&
                  cvvController.text.length >= 3 &&
                  nameController.text.isNotEmpty) {
                setState(() {
                  _paymentMethods.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'type': 'card',
                    'cardType': 'Visa', // Detectar tipo de tarjeta
                    'lastFourDigits': cardNumberController.text.substring(
                      cardNumberController.text.length - 4,
                    ),
                    'expiryDate': expiryController.text,
                    'isDefault': false,
                  });
                });
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tarjeta agregada exitosamente'),
                    backgroundColor: Colors.black87,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Agregar',
              style: TextStyle(color: Color(0xFFFFFF00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFFF00)),
            ),
          ),
        ),
      ],
    );
  }
}

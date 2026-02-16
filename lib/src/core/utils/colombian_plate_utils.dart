import 'package:flutter/services.dart';

class ColombianPlateUtils {
  static final RegExp _vehiclePlatePattern = RegExp(r'^[A-Z]{3}[0-9]{3}$');
  static final RegExp _motorcyclePlatePattern = RegExp(r'^[A-Z]{3}[0-9]{2}[A-Z]$');

  static String normalize(String input) {
    final normalized = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.length <= 6) {
      return normalized;
    }
    return normalized.substring(0, 6);
  }

  static bool isValid(String input) {
    final plate = normalize(input);
    return _vehiclePlatePattern.hasMatch(plate) ||
        _motorcyclePlatePattern.hasMatch(plate);
  }

  static String? validate(String? value, {bool required = true}) {
    final plate = normalize(value ?? '');

    if (required && plate.isEmpty) {
      return 'Ingresa la placa';
    }

    if (plate.isEmpty) {
      return null;
    }

    if (!isValid(plate)) {
      return 'Formato inválido. Usa ABC123 o ABC12D';
    }

    return null;
  }

  static String formatForDisplay(String? input, {String fallback = '---'}) {
    final plate = normalize(input ?? '');
    if (plate.isEmpty) {
      return fallback;
    }

    if (plate.length <= 3) {
      return plate;
    }

    return '${plate.substring(0, 3)}-${plate.substring(3)}';
  }
}

class ColombianPlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = ColombianPlateUtils.normalize(newValue.text);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }
}
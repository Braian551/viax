class PhoneNumberFormatter {
  const PhoneNumberFormatter._();

  static String normalizeInternational({
    required String dialCode,
    required String rawPhone,
  }) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      return '+${trimmed.replaceAll(RegExp(r'[^0-9]'), '')}';
    }

    if (trimmed.startsWith('00')) {
      return '+${trimmed.substring(2).replaceAll(RegExp(r'[^0-9]'), '')}';
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    final dialDigits = dialCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || dialDigits.isEmpty) return digits;

    if (digits.startsWith(dialDigits) && digits.length > dialDigits.length + 6) {
      return '+$digits';
    }

    return '+$dialDigits$digits';
  }
}

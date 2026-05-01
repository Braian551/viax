double normalizeCopApprox(double value, {int step = 100}) {
  final safeStep = step <= 0 ? 1 : step;
  final sanitized = value.isFinite ? value : 0;
  final positive = sanitized < 0 ? 0 : sanitized;
  return (positive / safeStep).round() * safeStep.toDouble();
}

String formatCurrency(double value, {bool withSymbol = true}) {
  final formatted = normalizeCopApprox(value)
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
  return withSymbol ? '\$$formatted' : formatted;
}

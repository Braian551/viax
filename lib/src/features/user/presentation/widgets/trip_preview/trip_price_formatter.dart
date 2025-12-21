String formatCurrency(double value, {bool withSymbol = true}) {
  final formatted = value
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
  return withSymbol ? '\$$formatted' : formatted;
}

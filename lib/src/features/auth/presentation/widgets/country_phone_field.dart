import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/global/services/phone_country_service.dart';
import 'package:viax/src/theme/app_colors.dart';

class CountryPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final PhoneCountry selectedCountry;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final String label;
  final bool isRequired;
  final String? Function(String?)? validator;

  const CountryPhoneField({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.label,
    this.isRequired = false,
    this.validator,
  });

  @override
  State<CountryPhoneField> createState() => _CountryPhoneFieldState();
}

class _CountryPhoneFieldState extends State<CountryPhoneField> {
  List<PhoneCountry> _countries = const [PhoneCountryService.colombia];
  bool _isLoadingCountries = false;
  bool _didApplySuggestedCountry = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() => _isLoadingCountries = true);
    final countries = await PhoneCountryService.loadCountries();
    final suggestedCountry = await PhoneCountryService.detectSuggestedCountry();
    if (!mounted) return;
    setState(() {
      _countries = countries;
      _isLoadingCountries = false;
    });
    _applySuggestedCountry(suggestedCountry);
  }

  // Aplicar la sugerencia una sola vez evita pisar una selección manual posterior.
  void _applySuggestedCountry(PhoneCountry suggestedCountry) {
    if (_didApplySuggestedCountry) return;

    _didApplySuggestedCountry = true;
    final currentCountry = widget.selectedCountry;
    if (currentCountry.isoCode != PhoneCountryService.colombia.isoCode) {
      return;
    }

    if (suggestedCountry.isoCode == currentCountry.isoCode) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCountryChanged(suggestedCountry);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final surfaceColor = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.8)
        : AppColors.lightSurface.withValues(alpha: 0.8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountryCodeButton(
          countries: _countries,
          selectedCountry: widget.selectedCountry,
          isLoading: _isLoadingCountries,
          onChanged: widget.onCountryChanged,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppColors.darkShadow : AppColors.lightShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextFormField(
              controller: widget.controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
                LengthLimitingTextInputFormatter(18),
              ],
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                hintText: 'Ingresa tu número',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
              ),
              validator: widget.validator ?? _defaultValidator,
            ),
          ),
        ),
      ],
    );
  }

  String? _defaultValidator(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (widget.isRequired && digits.isEmpty) return 'Requerido';
    if (digits.isNotEmpty && digits.length < 7) return 'Min 7 dígitos';
    return null;
  }
}

class _CountryCodeButton extends StatelessWidget {
  final List<PhoneCountry> countries;
  final PhoneCountry selectedCountry;
  final bool isLoading;
  final ValueChanged<PhoneCountry> onChanged;

  const _CountryCodeButton({
    required this.countries,
    required this.selectedCountry,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isLoading ? null : () => _showCountrySelector(context),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.8)
              : AppColors.lightSurface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCountry.dialCode,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCountrySelector(BuildContext context) async {
    final selected = await showModalBottomSheet<PhoneCountry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CountrySelectorSheet(
          countries: countries,
          selectedCountry: selectedCountry,
        );
      },
    );

    if (selected != null) {
      onChanged(selected);
    }
  }
}

class _CountrySelectorSheet extends StatefulWidget {
  final List<PhoneCountry> countries;
  final PhoneCountry selectedCountry;

  const _CountrySelectorSheet({
    required this.countries,
    required this.selectedCountry,
  });

  @override
  State<_CountrySelectorSheet> createState() => _CountrySelectorSheetState();
}

class _CountrySelectorSheetState extends State<_CountrySelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Mantener el país activo arriba reduce el desplazamiento para confirmar el prefijo.
  List<PhoneCountry> get _visibleCountries {
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredCountries = normalizedQuery.isEmpty
        ? List<PhoneCountry>.from(widget.countries)
        : widget.countries.where((country) {
            return country.name.toLowerCase().contains(normalizedQuery) ||
                country.isoCode.toLowerCase().contains(normalizedQuery) ||
                country.dialCode.contains(normalizedQuery);
          }).toList();

    filteredCountries.sort((left, right) {
      final leftSelected = left.isoCode == widget.selectedCountry.isoCode;
      final rightSelected = right.isoCode == widget.selectedCountry.isoCode;
      if (leftSelected == rightSelected) {
        return left.name.compareTo(right.name);
      }
      return leftSelected ? -1 : 1;
    });

    return filteredCountries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleCountries = _visibleCountries;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona tu país',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Busca por nombre, ISO o prefijo internacional.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar país o código',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar búsqueda',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
              Expanded(
                child: visibleCountries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'No encontramos un país con ese criterio.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: visibleCountries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final country = visibleCountries[index];
                          final isSelected =
                              country.isoCode == widget.selectedCountry.isoCode;

                          return Material(
                            color: isSelected
                                ? colorScheme.primaryContainer.withValues(
                                    alpha: 0.55,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: Text(
                                country.label,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                country.isoCode,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              trailing: Text(
                                country.dialCode,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(country),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

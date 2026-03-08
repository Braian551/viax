import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'package:viax/src/features/company/presentation/widgets/drivers/company_driver_card.dart';
import 'package:viax/src/features/company/presentation/widgets/drivers/company_driver_details_sheet.dart';
import 'package:viax/src/features/company/presentation/screens/company_conductores_documentos_screen.dart';
import 'package:viax/src/features/company/presentation/screens/company_financial_history_sheet.dart';
import 'package:viax/src/theme/app_colors.dart';

class CompanyDriversTab extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyDriversTab({super.key, required this.user});

  @override
  State<CompanyDriversTab> createState() => _CompanyDriversTabState();
}

class _CompanyDriversTabState extends State<CompanyDriversTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _drivers = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadDrivers();
    });
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final empresaId = widget.user['empresa_id'] ?? widget.user['id'];
      
      var urlStr = '${AppConfig.baseUrl}/company/drivers.php?empresa_id=$empresaId';
      if (_searchController.text.isNotEmpty) {
        urlStr += '&search=${Uri.encodeComponent(_searchController.text)}';
      }

      final url = Uri.parse(urlStr);
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _drivers = List<Map<String, dynamic>>.from(data['data']['conductores'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDrivers, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Conductores',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${_drivers.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _drivers.isEmpty
             ? const Center(child: Text('No se encontraron conductores.'))
             : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _drivers.length,
              itemBuilder: (context, index) {
                final driver = _drivers[index];
                return CompanyDriverCard(
                  driver: driver,
                  onTap: () => _showDriverDetails(driver),
                );
              },
            ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark 
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)
            : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Buscar conductor por nombre, email...',
            prefixIcon: Icon(
              Icons.search_rounded, 
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompanyDriverDetailsSheet(
        driver: driver,
        onViewDocuments: () {
          Navigator.pop(context);
          _navigateToDocuments(driver);
        },
        onViewCommissions: () {
          Navigator.pop(context);
          _showFinancialHistory(driver);
        },
      ),
    );
  }

  Future<void> _showFinancialHistory(Map<String, dynamic> conductor) async {
    final empresaId = int.tryParse((widget.user['empresa_id'] ?? widget.user['id']).toString()) ?? 0;
    final actorUserId = int.tryParse((widget.user['id'] ?? '').toString()) ?? 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => DriverFinancialHistorySheet(
          driver: conductor,
          empresaId: empresaId,
          actorUserId: actorUserId,
          onPaymentRegistered: () {
            _loadDrivers();
          },
        ),
      ),
    );
  }

  void _navigateToDocuments(Map<String, dynamic> driver) {
    final empresaId = widget.user['empresa_id'] ?? widget.user['id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyConductoresDocumentosScreen(
          user: widget.user,
          empresaId: empresaId,
          initialUserId: driver['id'], // Pass ID
          initialSearch: driver['email'], // Pass email to filter
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.grey.withValues(alpha: 0.14);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.grey.withValues(alpha: 0.08);
    final blockColor = isDark
        ? AppColors.darkCard.withValues(alpha: 0.55)
        : Colors.white;

    return Column(
      children: [
        _buildSearchBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Conductores',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: 5,
            itemBuilder: (context, index) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 110,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

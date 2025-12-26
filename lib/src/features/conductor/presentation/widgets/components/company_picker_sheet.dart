import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/core/config/app_config.dart';
import 'dart:async';

class CompanyPickerSheet extends StatefulWidget {
  final bool isDark;
  final Function(Map<String, dynamic>?) onSelected;

  const CompanyPickerSheet({super.key, required this.isDark, required this.onSelected});

  @override
  State<CompanyPickerSheet> createState() => _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends State<CompanyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
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
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final results = await UserService.searchCompanies(query);
    if (mounted) {
      setState(() {
        _companies = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seleccionar Empresa',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: widget.isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Buscar empresa...',
              hintStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38),
              prefixIcon: Icon(Icons.search, color: widget.isDark ? Colors.white54 : Colors.black54),
              filled: true,
              fillColor: widget.isDark ? AppColors.darkCard : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          InkWell(
            onTap: () {
              widget.onSelected(null); // Independent
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Trabajar Independiente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          Text(
            'Resultados',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _companies.isEmpty 
                  ? Center(
                      child: Text(
                        'No se encontraron empresas',
                        style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _companies.length,
                      itemBuilder: (context, index) {
                        final company = _companies[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: widget.isDark ? AppColors.darkCard : Colors.grey[200],
                            backgroundImage: company['logo_url'] != null 
                              ? (company['logo_url'].toString().startsWith('http') 
                                  ? NetworkImage(company['logo_url']) 
                                  : NetworkImage('${AppConfig.baseUrl}/${company['logo_url']}'))
                              : null,
                            child: company['logo_url'] == null ? const Icon(Icons.business) : null,
                          ),
                          title: Text(
                            company['nombre'],
                            style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            widget.onSelected(company);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

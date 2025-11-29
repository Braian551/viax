import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../global/models/simple_location.dart';
import 'trip_preview_screen.dart';
import 'location_picker_screen.dart';

class RequestTripScreen extends StatefulWidget {
  final String? initialSelection;
  
  const RequestTripScreen({
    super.key,
    this.initialSelection,
  });

  @override
  State<RequestTripScreen> createState() => _RequestTripScreenState();
}

class _RequestTripScreenState extends State<RequestTripScreen> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  Timer? _debounce;
  
  SimpleLocation? _selectedOrigin;
  SimpleLocation? _selectedDestination;

  List<SimpleLocation> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    
    // Auto-fetch current location for origin
    _setCurrentLocation(isOrigin: true);

    _originController.addListener(() => _onTextChanged(isOrigin: true));
    _destinationController.addListener(() => _onTextChanged(isOrigin: false));
    _originFocusNode.addListener(() => setState(() {}));
    _destinationFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _isValid => _selectedOrigin != null && _selectedDestination != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildInputs()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildActionButtons()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSuggestionsList(),
                  _buildBottomButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            '¿A dónde vas?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _onInputTap({required bool isOrigin}) {
    setState(() {
      _suggestions = [];
    });
    final query = isOrigin ? _originController.text.trim() : _destinationController.text.trim();
    if (query.isNotEmpty) _searchLocation(query);
  }

  void _onTextChanged({required bool isOrigin}) {
    setState(() {}); // Rebuild to show/hide clear button
    
    final query = isOrigin ? _originController.text.trim() : _destinationController.text.trim();
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (query.isNotEmpty) {
        _searchLocation(query);
      } else {
        if (mounted) setState(() => _suggestions = []);
      }
    });
  }

  Widget _buildInputs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Hero(
        tag: 'search_destination_box',
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputField(
                    controller: _originController,
                    hint: 'Tu ubicación actual',
                    icon: Icons.my_location_outlined,
                    iconColor: const Color(0xFF2196F3),
                    isOrigin: true,
                  ),
                  Divider(height: 1, color: Colors.grey[200], indent: 56),
                  _buildInputField(
                    controller: _destinationController,
                    hint: '¿A dónde quieres ir?',
                    icon: Icons.location_on_outlined,
                    iconColor: const Color(0xFF2196F3),
                    isOrigin: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool isOrigin,
  }) {
    final hasFocus = isOrigin ? _originFocusNode.hasFocus : _destinationFocusNode.hasFocus;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hasFocus 
                ? iconColor.withOpacity(0.1) 
                : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon, 
              size: 18, 
              color: hasFocus ? iconColor : Colors.grey[500],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextFormField(
              focusNode: isOrigin ? _originFocusNode : _destinationFocusNode,
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: iconColor, width: 1.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                ),
                // Suffix icon inside the input, either clear button or loader
                suffixIcon: controller.text.isNotEmpty
                    ? Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() {
                            controller.clear();
                            _suggestions = [];
                            if (isOrigin) {
                              _selectedOrigin = null;
                            } else {
                              _selectedDestination = null;
                            }
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : ((_isLoadingSuggestions && hasFocus) || (isOrigin && _isGettingLocation))
                        ? Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                letterSpacing: -0.2,
              ),
              onTap: () => _onInputTap(isOrigin: isOrigin),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.my_location,
              label: 'Usar mi ubicación',
              onTap: () => _setCurrentLocation(isOrigin: true),
              isLoading: _isGettingLocation,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.map_outlined,
              label: 'Seleccionar en mapa',
              onTap: () async {
                LatLng? initialPos;
                if (_selectedOrigin != null) {
                  initialPos = LatLng(_selectedOrigin!.latitude, _selectedOrigin!.longitude);
                } else if (_selectedDestination != null) {
                  initialPos = LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude);
                }
                
                final result = await Navigator.push<SimpleLocation>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationPickerScreen(
                      initialPosition: initialPos,
                    ),
                  ),
                );

                if (result != null && mounted) {
                  final isOriginFocused = _originFocusNode.hasFocus;
                  final targetIsOrigin = isOriginFocused || (!_destinationFocusNode.hasFocus && _selectedOrigin == null);

                  setState(() {
                    if (targetIsOrigin) {
                      _selectedOrigin = result;
                      _originController.text = result.address;
                    } else {
                      _selectedDestination = result;
                      _destinationController.text = result.address;
                    }
                    _suggestions = [];
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  color: const Color(0xFF2196F3),
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2196F3),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if ((_originFocusNode.hasFocus || _destinationFocusNode.hasFocus) && _suggestions.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final suggestion = _suggestions[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final isOrigin = _originFocusNode.hasFocus;
                  setState(() {
                    if (isOrigin) {
                      _selectedOrigin = suggestion;
                      _originController.text = suggestion.address;
                    } else {
                      _selectedDestination = suggestion;
                      _destinationController.text = suggestion.address;
                    }
                    _suggestions = [];
                    FocusScope.of(context).unfocus();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF2196F3),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.address.split(',').first,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              suggestion.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                letterSpacing: -0.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200], indent: 50),
          itemCount: _suggestions.length,
        ),
      );
    }

    return Container();
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isValid
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TripPreviewScreen(
                        origin: _selectedOrigin!,
                        destination: _selectedDestination!,
                        vehicleType: 'carro',
                      ),
                    ),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: Text(
            'Confirmar ubicaciones',
            style: TextStyle(
              color: _isValid ? Colors.white : Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setCurrentLocation({required bool isOrigin}) async {
    if (_isGettingLocation) return;

    setState(() {
      _isGettingLocation = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilita la ubicación en el dispositivo')),
        );
        setState(() => _isGettingLocation = false);
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          setState(() => _isGettingLocation = false);
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado permanentemente')),
        );
        setState(() => _isGettingLocation = false);
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final address = await _reverseGeocode(position.latitude, position.longitude);
      final location = SimpleLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address ?? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      );
      
      if (mounted) {
        setState(() {
          if (isOrigin) {
            _selectedOrigin = location;
            _originController.text = location.address;
          } else {
            _selectedDestination = location;
            _destinationController.text = location.address;
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon');
      final resp = await http.get(url, headers: {
        'User-Agent': 'ViaxApp/1.0 (student_project_demo)'
      });
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      } else {
        debugPrint('Reverse geocode failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return null;
  }

  Future<void> _searchLocation(String query) async {
    setState(() {
      _isLoadingSuggestions = true;
    });
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=jsonv2&addressdetails=1&limit=6');
      final resp = await http.get(url, headers: {
        'User-Agent': 'ViaxApp/1.0 (student_project_demo)'
      });
      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body) as List;
        final results = data.map((item) => SimpleLocation(
          latitude: double.tryParse(item['lat']?.toString() ?? '0') ?? 0,
          longitude: double.tryParse(item['lon']?.toString() ?? '0') ?? 0,
          address: item['display_name'] ?? '',
        )).toList();
        if (mounted) {
          setState(() => _suggestions = results.cast<SimpleLocation>());
        }
      } else {
        debugPrint('Search failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Nominatim search error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
      }
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';
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

class _RequestTripScreenState extends State<RequestTripScreen> with TickerProviderStateMixin {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  
  // Multiple stops state
  final List<SimpleLocation> _stops = [];
  final List<TextEditingController> _stopControllers = [];
  final List<FocusNode> _stopFocusNodes = [];
  
  Timer? _debounce;
  
  SimpleLocation? _selectedOrigin;
  SimpleLocation? _selectedDestination;

  List<SimpleLocation> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _isGettingLocation = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _setupAnimations();
    
    // Auto-fetch current location for origin (non-blocking)
    Future.microtask(() => _setCurrentLocation(targetField: 'origin'));

    _originController.addListener(() => _onTextChanged(targetField: 'origin'));
    _destinationController.addListener(() => _onTextChanged(targetField: 'destination'));
    _originFocusNode.addListener(() => setState(() {}));
    _destinationFocusNode.addListener(() => setState(() {}));
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    
    for (var controller in _stopControllers) controller.dispose();
    for (var node in _stopFocusNodes) node.dispose();
    
    _debounce?.cancel();
    super.dispose();
  }

  bool get _isValid => _selectedOrigin != null && _selectedDestination != null && 
      (_stops.length == _stopControllers.length); // Basic validation

  void _addStop() {
    if (_stops.length >= 3) return; // Max 3 stops
    
    setState(() {
      _stops.add(SimpleLocation(latitude: 0, longitude: 0, address: '')); // Placeholder
      final controller = TextEditingController();
      final focusNode = FocusNode();
      
      controller.addListener(() => _onTextChanged(targetField: 'stop_${_stops.length - 1}'));
      focusNode.addListener(() => setState(() {}));
      
      _stopControllers.add(controller);
      _stopFocusNodes.add(focusNode);
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      _stopControllers[index].dispose();
      _stopControllers.removeAt(index);
      _stopFocusNodes[index].dispose();
      _stopFocusNodes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient or map placeholder if needed, for now just color
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [AppColors.darkSurface, AppColors.darkBackground]
                  : [AppColors.lightSurface, AppColors.lightBackground],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildInputs(isDark),
                          const SizedBox(height: 16),
                          _buildActionButtons(isDark),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildSuggestionsList(isDark),
                          ),
                          _buildBottomButton(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.white.withOpacity(0.7)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isDark 
                          ? Colors.white.withOpacity(0.2) 
                          : Colors.white.withOpacity(0.4)),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded, 
                      color: isDark ? Colors.white : Colors.black87, 
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '¿A dónde vas?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (_stops.length < 3)
            IconButton(
              onPressed: _addStop,
              icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? Colors.white : Colors.black87),
              tooltip: 'Agregar parada',
            ),
        ],
      ),
    );
  }

  Future<void> _onInputTap({required String targetField}) async {
    setState(() {
      _suggestions = [];
    });
    
    String query = '';
    if (targetField == 'origin') {
      query = _originController.text.trim();
    } else if (targetField == 'destination') {
      query = _destinationController.text.trim();
    } else if (targetField.startsWith('stop_')) {
      final index = int.parse(targetField.split('_')[1]);
      query = _stopControllers[index].text.trim();
    }

    if (query.isNotEmpty) {
      // Don't await here - let it run asynchronously to avoid blocking UI
      _searchLocation(query);
    }
  }

  void _onTextChanged({required String targetField}) {
    setState(() {}); // Rebuild to show/hide clear button
    
    String query = '';
    if (targetField == 'origin') {
      query = _originController.text.trim();
    } else if (targetField == 'destination') {
      query = _destinationController.text.trim();
    } else if (targetField.startsWith('stop_')) {
      final index = int.parse(targetField.split('_')[1]);
      query = _stopControllers[index].text.trim();
    }
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (query.isNotEmpty) {
        _searchLocation(query);
      } else {
        if (mounted) setState(() => _suggestions = []);
      }
    });
  }

  Widget _buildInputs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Hero(
        tag: 'search_destination_box',
        child: Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInputField(
                      controller: _originController,
                      focusNode: _originFocusNode,
                      hint: 'Tu ubicación actual',
                      icon: Icons.my_location_rounded,
                      iconColor: AppColors.primary,
                      targetField: 'origin',
                      isDark: isDark,
                    ),
                    
                    // Render stops
                    for (int i = 0; i < _stopControllers.length; i++) ...[
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 70),
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                      _buildInputField(
                        controller: _stopControllers[i],
                        focusNode: _stopFocusNodes[i],
                        hint: 'Parada ${i + 1}',
                        icon: Icons.stop_circle_outlined,
                        iconColor: AppColors.warning,
                        targetField: 'stop_$i',
                        isDark: isDark,
                        onRemove: () => _removeStop(i),
                      ),
                    ],

                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 70),
                      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    ),
                    _buildInputField(
                      controller: _destinationController,
                      focusNode: _destinationFocusNode,
                      hint: '¿A dónde quieres ir?',
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.error,
                      targetField: 'destination',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required String targetField,
    required bool isDark,
    VoidCallback? onRemove,
  }) {
    final hasFocus = focusNode.hasFocus;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextFormField(
              focusNode: focusNode,
              controller: controller,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                letterSpacing: -0.3,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() {
                          controller.clear();
                          _suggestions = [];
                          if (targetField == 'origin') {
                            _selectedOrigin = null;
                          } else if (targetField == 'destination') {
                            _selectedDestination = null;
                          } else if (targetField.startsWith('stop_')) {
                             // Keep the stop in list but clear data
                             final index = int.parse(targetField.split('_')[1]);
                             _stops[index] = SimpleLocation(latitude: 0, longitude: 0, address: '');
                          }
                        }),
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkDivider : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
                          ),
                        ),
                      ),
                    
                    if (onRemove != null)
                       GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                            color: isDark ? AppColors.darkTextHint : Colors.grey[400],
                          ),
                        ),
                      ),

                    if ((_isLoadingSuggestions && hasFocus) || (targetField == 'origin' && _isGettingLocation))
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              onTap: () => _onInputTap(targetField: targetField),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.my_location_rounded,
              label: 'Mi ubicación',
              onTap: () {
                // Determine which field to set
                String target = 'origin';
                if (_destinationFocusNode.hasFocus) target = 'destination';
                for (int i = 0; i < _stopFocusNodes.length; i++) {
                  if (_stopFocusNodes[i].hasFocus) target = 'stop_$i';
                }
                _setCurrentLocation(targetField: target);
              },
              isLoading: _isGettingLocation,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.map_rounded,
              label: 'Mapa',
              onTap: () async {
                LatLng? initialPos;
                // Try to get position from currently selected field or origin
                if (_selectedOrigin != null) {
                  initialPos = LatLng(_selectedOrigin!.latitude, _selectedOrigin!.longitude);
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
                  setState(() {
                    if (_originFocusNode.hasFocus || (!_destinationFocusNode.hasFocus && _stopFocusNodes.every((n) => !n.hasFocus) && _selectedOrigin == null)) {
                      _selectedOrigin = result;
                      _originController.text = result.address;
                    } else if (_destinationFocusNode.hasFocus) {
                      _selectedDestination = result;
                      _destinationController.text = result.address;
                    } else {
                      // Check stops
                      for (int i = 0; i < _stopFocusNodes.length; i++) {
                        if (_stopFocusNodes[i].hasFocus) {
                          _stops[i] = result;
                          _stopControllers[i].text = result.address;
                          break;
                        }
                      }
                    }
                    _suggestions = [];
                  });
                }
              },
              isDark: isDark,
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
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(isDark ? 0.1 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(bool isDark) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_originFocusNode.hasFocus) {
                      _selectedOrigin = suggestion;
                      _originController.text = suggestion.address;
                    } else if (_destinationFocusNode.hasFocus) {
                      _selectedDestination = suggestion;
                      _destinationController.text = suggestion.address;
                    } else {
                       for (int i = 0; i < _stopFocusNodes.length; i++) {
                        if (_stopFocusNodes[i].hasFocus) {
                          _stops[i] = suggestion;
                          _stopControllers[i].text = suggestion.address;
                          break;
                        }
                      }
                    }
                    _suggestions = [];
                    FocusScope.of(context).unfocus();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.address.split(',').first,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suggestion.address,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomButton(bool isDark) {
    if (!_isValid) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                // Filter out empty stops just in case
                final validStops = _stops.where((s) => s.latitude != 0 && s.longitude != 0).toList();
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripPreviewScreen(
                      origin: _selectedOrigin!,
                      destination: _selectedDestination!,
                      stops: validStops, // Pass stops
                      vehicleType: 'auto',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Confirmar ubicaciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setCurrentLocation({required String targetField}) async {
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
          if (targetField == 'origin') {
            _selectedOrigin = location;
            _originController.text = location.address;
          } else if (targetField == 'destination') {
            _selectedDestination = location;
            _destinationController.text = location.address;
          } else if (targetField.startsWith('stop_')) {
             final index = int.parse(targetField.split('_')[1]);
             _stops[index] = location;
             _stopControllers[index].text = location.address;
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

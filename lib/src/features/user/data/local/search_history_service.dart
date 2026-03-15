import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryItem {
  final String address;
  final double lat;
  final double lng;
  final int updatedAtMs;

  const SearchHistoryItem({
    required this.address,
    required this.lat,
    required this.lng,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'lat': lat,
        'lng': lng,
        'updatedAtMs': updatedAtMs,
      };

  static SearchHistoryItem? fromJson(Map<String, dynamic> json) {
    final address = (json['address'] ?? '').toString().trim();
    if (address.isEmpty) return null;

    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return SearchHistoryItem(
      address: address,
      lat: lat,
      lng: lng,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class SearchHistoryService {
  static const int _maxItems = 10;
  final int userId;

  const SearchHistoryService({required this.userId});

  String get _prefsKey => 'search_history:user:$userId';

  Future<void> saveSearch(String address, double lat, double lng) async {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await getRecentSearches();

    // De-duplicate by address (case-insensitive) and close coordinates.
    final filtered = current.where((item) {
      final sameAddress =
          item.address.toLowerCase() == normalizedAddress.toLowerCase();
      final samePoint =
          (item.lat - lat).abs() < 0.0001 && (item.lng - lng).abs() < 0.0001;
      return !(sameAddress || samePoint);
    }).toList();

    filtered.insert(
      0,
      SearchHistoryItem(
        address: normalizedAddress,
        lat: lat,
        lng: lng,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    final bounded = filtered.take(_maxItems).toList();
    final encoded = jsonEncode(bounded.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<List<SearchHistoryItem>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return <SearchHistoryItem>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SearchHistoryItem>[];

      return decoded
          .whereType<Map>()
          .map((e) => SearchHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .whereType<SearchHistoryItem>()
          .toList();
    } catch (_) {
      return <SearchHistoryItem>[];
    }
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

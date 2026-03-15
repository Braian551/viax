import 'package:flutter/material.dart';

/// Pricing details calculated for a route.
class TripQuote {
  final double distanceKm;
  final int durationMinutes;
  final double basePrice;
  final double distancePrice;
  final double timePrice;
  final double surchargePrice;
  final double totalPrice;
  final String periodType; // 'normal', 'hora_pico', 'nocturno'
  final double surchargePercentage;
  final double surgeMultiplier;
  final double? pickupEtaMinutes;
  final double? driverDistanceKm;
  final int? companyId;
  final String? companyName;
  final String? companyLogoUrl;
  final bool isRandomEstimate;
  final int randomCompanyCount;

  TripQuote({
    required this.distanceKm,
    required this.durationMinutes,
    required this.basePrice,
    required this.distancePrice,
    required this.timePrice,
    required this.surchargePrice,
    required this.totalPrice,
    required this.periodType,
    required this.surchargePercentage,
    this.surgeMultiplier = 1.0,
    this.pickupEtaMinutes,
    this.driverDistanceKm,
    this.companyId,
    this.companyName,
    this.companyLogoUrl,
    this.isRandomEstimate = false,
    this.randomCompanyCount = 0,
  });

  TripQuote copyWith({
    double? distanceKm,
    int? durationMinutes,
    double? basePrice,
    double? distancePrice,
    double? timePrice,
    double? surchargePrice,
    double? totalPrice,
    String? periodType,
    double? surchargePercentage,
    double? surgeMultiplier,
    double? pickupEtaMinutes,
    double? driverDistanceKm,
    int? companyId,
    String? companyName,
    String? companyLogoUrl,
    bool? isRandomEstimate,
    int? randomCompanyCount,
  }) {
    return TripQuote(
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      basePrice: basePrice ?? this.basePrice,
      distancePrice: distancePrice ?? this.distancePrice,
      timePrice: timePrice ?? this.timePrice,
      surchargePrice: surchargePrice ?? this.surchargePrice,
      totalPrice: totalPrice ?? this.totalPrice,
      periodType: periodType ?? this.periodType,
      surchargePercentage: surchargePercentage ?? this.surchargePercentage,
      surgeMultiplier: surgeMultiplier ?? this.surgeMultiplier,
      pickupEtaMinutes: pickupEtaMinutes ?? this.pickupEtaMinutes,
      driverDistanceKm: driverDistanceKm ?? this.driverDistanceKm,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      isRandomEstimate: isRandomEstimate ?? this.isRandomEstimate,
      randomCompanyCount: randomCompanyCount ?? this.randomCompanyCount,
    );
  }

  factory TripQuote.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    int toInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return TripQuote(
      distanceKm: toDouble(json['distance_km'] ?? json['distanceKm']),
      durationMinutes: toInt(
        json['duration_minutes'] ?? json['durationMinutes'],
      ),
      basePrice: toDouble(json['base_price'] ?? json['basePrice']),
      distancePrice: toDouble(json['distance_price'] ?? json['distancePrice']),
      timePrice: toDouble(json['time_price'] ?? json['timePrice']),
      surchargePrice: toDouble(
        json['surcharge_price'] ?? json['surchargePrice'],
      ),
      totalPrice: toDouble(json['total_price'] ?? json['totalPrice']),
      periodType: (json['period_type'] ?? json['periodType'] ?? 'normal')
          .toString(),
      surchargePercentage: toDouble(
        json['surcharge_percentage'] ?? json['surchargePercentage'],
      ),
      pickupEtaMinutes: toDouble(
        json['pickupEtaMinutes'] ?? json['pickup_eta_minutes'],
      ),
      surgeMultiplier: toDouble(
        json['surgeMultiplier'] ?? json['surge_multiplier'],
        fallback: 1.0,
      ),
      driverDistanceKm: toDouble(
        json['driverDistance'] ?? json['driver_distance'],
      ),
      companyId: (() {
        final raw = json['company_id'] ?? json['companyId'];
        final parsed = toInt(raw, fallback: 0);
        return parsed > 0 ? parsed : null;
      })(),
      companyName: (json['company_name'] ?? json['companyName'])?.toString(),
      companyLogoUrl: (json['company_logo_url'] ??
              json['companyLogoUrl'])
          ?.toString(),
      isRandomEstimate:
          (json['is_random_estimate'] ?? json['isRandomEstimate']) == true,
      randomCompanyCount: toInt(
        json['random_company_count'] ?? json['randomCompanyCount'],
      ),
    );
  }

  String get formattedTotal => '\$${_formatNumber(totalPrice)}';
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';
  String get formattedDuration => '$durationMinutes min';
  String get formattedPickupEta => pickupEtaMinutes == null
      ? '--'
      : '${pickupEtaMinutes!.round()} min';
  String get formattedDriverDistance => driverDistanceKm == null
      ? '--'
      : '${driverDistanceKm!.toStringAsFixed(1)} km';

  String _formatNumber(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.'
        );
  }
}

/// Static specs for the available vehicles.
class VehicleInfo {
  final String type;
  final String name;
  final String description;
  final IconData icon;
  final String imagePath;
  final String? pinIconPath;
  final Map<String, double> config;

  const VehicleInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.imagePath,
    this.pinIconPath,
    required this.config,
  });
}

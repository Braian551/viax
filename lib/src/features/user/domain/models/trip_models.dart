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
    );
  }

  String get formattedTotal => '\$${_formatNumber(totalPrice)}';
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';
  String get formattedDuration => '$durationMinutes min';

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

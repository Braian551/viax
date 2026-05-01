import 'package:flutter/foundation.dart';

enum SearchFlowState {
  confirmingDestination,
  selectingFare,
  searchingDriver,
  driverFound,
}

@immutable
class DriverPreview {
  final String name;
  final double rating;
  final int etaMinutes;
  final String? photoUrl;

  const DriverPreview({
    required this.name,
    required this.rating,
    required this.etaMinutes,
    this.photoUrl,
  });

  /// Construye un DriverPreview desde el mapa driver_checking del backend.
  /// Devuelve null si el mapa no contiene un nombre válido.
  static DriverPreview? fromDriverChecking(Map<String, dynamic>? json) {
    if (json == null) return null;

    final rawName =
        (json['name'] ?? json['nombre'] ?? json['driver_name'] ?? '')
            .toString()
            .trim();
    if (rawName.isEmpty) return null;

    final rawRating = json['rating'] ?? json['calificacion'] ?? json['score'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse('$rawRating') ?? 4.8;

    final rawEta =
        json['eta'] ??
        json['eta_minutes'] ??
        json['eta_min'] ??
        json['eta_minutos'];
    final etaMinutes = rawEta is num
        ? rawEta.toInt()
        : int.tryParse('$rawEta') ?? 3;

    final photo = (json['photo'] ?? json['foto'] ?? json['avatar'] ?? '')
        .toString()
        .trim();

    return DriverPreview(
      name: rawName,
      rating: rating,
      etaMinutes: etaMinutes,
      photoUrl: photo.isEmpty ? null : photo,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DriverPreview &&
      other.name == name &&
      other.rating == rating &&
      other.etaMinutes == etaMinutes &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(name, rating, etaMinutes, photoUrl);
}

@immutable
class CompanyPreview {
  final int id;
  final String name;
  final String logoUrl;

  const CompanyPreview({
    required this.id,
    required this.name,
    required this.logoUrl,
  });
}

@immutable
class SearchingDriverState {
  final SearchFlowState flowState;
  final double searchRadiusKm;
  final int currentRadiusKm;
  final int currentStageIndex;
  final int secondsInStage;
  final String radiusLabel;
  final int totalSecondsElapsed;
  final String matchingStatus;
  final String uiMessage;

  /// Conductor actualmente visible en la UI.
  /// Null significa que aún no hay ningún conductor real del backend.
  final DriverPreview? visibleDriver;

  /// True cuando el backend devolvió al menos un conductor real durante la sesión.
  final bool hasRealDrivers;

  /// Conductores disponibles en el radio actual según el backend (conductores_cerca).
  final int nearbyDriverCount;

  final CompanyPreview? currentCompany;
  final int elapsedSeconds;
  final String searchMode;
  final bool isCancelling;
  final bool noDriverTerminal;
  final int dynamicMessageIndex;
  final double sheetSize;

  const SearchingDriverState({
    required this.flowState,
    required this.searchRadiusKm,
    required this.currentRadiusKm,
    required this.currentStageIndex,
    required this.secondsInStage,
    required this.radiusLabel,
    required this.totalSecondsElapsed,
    required this.matchingStatus,
    required this.uiMessage,
    required this.visibleDriver,
    required this.hasRealDrivers,
    required this.nearbyDriverCount,
    required this.currentCompany,
    required this.elapsedSeconds,
    required this.searchMode,
    required this.isCancelling,
    required this.noDriverTerminal,
    required this.dynamicMessageIndex,
    required this.sheetSize,
  });

  static const Object _sentinel = Object();

  factory SearchingDriverState.initial({
    CompanyPreview? initialCompany,
    SearchFlowState initialFlowState = SearchFlowState.searchingDriver,
  }) {
    return SearchingDriverState(
      flowState: initialFlowState,
      searchRadiusKm: 2.0,
      currentRadiusKm: 2,
      currentStageIndex: 0,
      secondsInStage: 0,
      radiusLabel: 'Buscando cerca de ti',
      totalSecondsElapsed: 0,
      matchingStatus: 'searching',
      uiMessage: '',
      visibleDriver: null,
      hasRealDrivers: false,
      nearbyDriverCount: 0,
      currentCompany: initialCompany,
      elapsedSeconds: 0,
      searchMode: initialCompany == null ? 'azar' : 'empresa',
      isCancelling: false,
      noDriverTerminal: false,
      dynamicMessageIndex: 0,
      sheetSize: 0.28,
    );
  }

  SearchingDriverState copyWith({
    SearchFlowState? flowState,
    double? searchRadiusKm,
    int? currentRadiusKm,
    int? currentStageIndex,
    int? secondsInStage,
    String? radiusLabel,
    int? totalSecondsElapsed,
    String? matchingStatus,
    String? uiMessage,
    Object? visibleDriver = _sentinel,
    bool? hasRealDrivers,
    int? nearbyDriverCount,
    Object? currentCompany = _sentinel,
    int? elapsedSeconds,
    String? searchMode,
    bool? isCancelling,
    bool? noDriverTerminal,
    int? dynamicMessageIndex,
    double? sheetSize,
  }) {
    return SearchingDriverState(
      flowState: flowState ?? this.flowState,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      currentRadiusKm: currentRadiusKm ?? this.currentRadiusKm,
      currentStageIndex: currentStageIndex ?? this.currentStageIndex,
      secondsInStage: secondsInStage ?? this.secondsInStage,
      radiusLabel: radiusLabel ?? this.radiusLabel,
      totalSecondsElapsed: totalSecondsElapsed ?? this.totalSecondsElapsed,
      matchingStatus: matchingStatus ?? this.matchingStatus,
      uiMessage: uiMessage ?? this.uiMessage,
      visibleDriver: identical(visibleDriver, _sentinel)
          ? this.visibleDriver
          : visibleDriver as DriverPreview?,
      hasRealDrivers: hasRealDrivers ?? this.hasRealDrivers,
      nearbyDriverCount: nearbyDriverCount ?? this.nearbyDriverCount,
      currentCompany: identical(currentCompany, _sentinel)
          ? this.currentCompany
          : currentCompany as CompanyPreview?,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      searchMode: searchMode ?? this.searchMode,
      isCancelling: isCancelling ?? this.isCancelling,
      noDriverTerminal: noDriverTerminal ?? this.noDriverTerminal,
      dynamicMessageIndex: dynamicMessageIndex ?? this.dynamicMessageIndex,
      sheetSize: sheetSize ?? this.sheetSize,
    );
  }
}

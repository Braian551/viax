import 'package:viax/src/global/models/simple_location.dart';

enum SavedPlaceType { home, work, favorite }

extension SavedPlaceTypeX on SavedPlaceType {
  String get apiValue {
    switch (this) {
      case SavedPlaceType.home:
        return 'home';
      case SavedPlaceType.work:
        return 'work';
      case SavedPlaceType.favorite:
        return 'favorite';
    }
  }

  String get label {
    switch (this) {
      case SavedPlaceType.home:
        return 'Casa';
      case SavedPlaceType.work:
        return 'Trabajo';
      case SavedPlaceType.favorite:
        return 'Favorito';
    }
  }
}

SavedPlaceType savedPlaceTypeFromApi(String rawType) {
  switch (rawType.trim().toLowerCase()) {
    case 'home':
      return SavedPlaceType.home;
    case 'work':
      return SavedPlaceType.work;
    case 'favorite':
    default:
      return SavedPlaceType.favorite;
  }
}

double _savedPlaceAsDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String? _savedPlaceAsString(dynamic value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

class SavedUserPlace {
  final int id;
  final SavedPlaceType type;
  final String name;
  final SimpleLocation location;

  const SavedUserPlace({
    required this.id,
    required this.type,
    required this.name,
    required this.location,
  });

  bool get isFavorite => type == SavedPlaceType.favorite;

  SimpleLocation get selectionLocation => location.copyWith(
    placeName: name,
    subtitle: location.address,
  );

  factory SavedUserPlace.fromMap(Map<String, dynamic> map) {
    final type = savedPlaceTypeFromApi(
      map['tipo_guardado']?.toString() ?? map['place_type']?.toString() ?? '',
    );
    final address = _savedPlaceAsString(map['direccion']) ?? 'Direccion guardada';
    final explicitName = _savedPlaceAsString(map['nombre_guardado']);
    final fallbackName = explicitName ??
        (type == SavedPlaceType.favorite
            ? address.split(',').first.trim()
            : type.label);

    return SavedUserPlace(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      type: type,
      name: fallbackName,
      location: SimpleLocation(
        latitude: _savedPlaceAsDouble(map['latitud']),
        longitude: _savedPlaceAsDouble(map['longitud']),
        address: address,
        placeName: fallbackName,
        subtitle: address,
        municipality: _savedPlaceAsString(map['ciudad']),
        department: _savedPlaceAsString(map['departamento']),
        country: _savedPlaceAsString(map['pais']),
        sourceType: 'saved_place',
      ),
    );
  }
}

class SavedPlacesCollection {
  final SavedUserPlace? home;
  final SavedUserPlace? work;
  final List<SavedUserPlace> favorites;

  const SavedPlacesCollection({
    this.home,
    this.work,
    this.favorites = const [],
  });

  const SavedPlacesCollection.empty()
    : home = null,
      work = null,
      favorites = const [];

  bool get hasFavorites => favorites.isNotEmpty;

  SavedUserPlace? byType(SavedPlaceType type) {
    switch (type) {
      case SavedPlaceType.home:
        return home;
      case SavedPlaceType.work:
        return work;
      case SavedPlaceType.favorite:
        return null;
    }
  }

  SavedPlacesCollection copyWith({
    SavedUserPlace? home,
    SavedUserPlace? work,
    List<SavedUserPlace>? favorites,
  }) {
    return SavedPlacesCollection(
      home: home ?? this.home,
      work: work ?? this.work,
      favorites: favorites ?? this.favorites,
    );
  }

  factory SavedPlacesCollection.fromResponse(Map<String, dynamic> response) {
    final data = response['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(response['data'] as Map<String, dynamic>)
        : response;

    final rawFavorites = data['favorites'] as List? ?? const [];

    return SavedPlacesCollection(
      home: data['home'] is Map<String, dynamic>
          ? SavedUserPlace.fromMap(
              Map<String, dynamic>.from(data['home'] as Map<String, dynamic>),
            )
          : null,
      work: data['work'] is Map<String, dynamic>
          ? SavedUserPlace.fromMap(
              Map<String, dynamic>.from(data['work'] as Map<String, dynamic>),
            )
          : null,
      favorites: rawFavorites
          .whereType<Map>()
          .map(
            (item) => SavedUserPlace.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}
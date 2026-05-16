import 'package:flutter/material.dart';
import 'package:viax/src/features/user/data/models/saved_user_place.dart';
import 'package:viax/src/features/user/presentation/screens/saved_place_name_screen.dart';
import 'package:viax/src/features/user/presentation/widgets/destination/location_search_sheet.dart';
import 'package:viax/src/features/user/services/saved_places_service.dart';
import 'package:viax/src/global/models/simple_location.dart';
import 'package:viax/src/global/services/location_suggestion_service.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final LocationSuggestionService _suggestionService = LocationSuggestionService();

  SavedPlacesCollection _savedPlaces = const SavedPlacesCollection.empty();
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces({bool forceRefresh = false}) async {
    try {
      final places = await SavedPlacesService.loadForCurrentUser(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        _savedPlaces = places;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('No pudimos cargar tus direcciones', isError: true);
    }
  }

  Future<void> _handleHomeOrWorkTap(SavedPlaceType type) async {
    if (_isBusy) return;

    final current = _savedPlaces.byType(type);
    final location = await _pickLocation(
      title: type == SavedPlaceType.home
          ? 'Direccion de tu casa'
          : 'Direccion de tu trabajo',
      currentValue: current?.location,
      type: type,
    );

    if (location == null) return;

    await _savePlace(type: type, location: location, existing: current);
  }

  Future<void> _handleFavoriteTap([SavedUserPlace? existing]) async {
    if (_isBusy) return;

    final location = await _pickLocation(
      title: existing == null ? 'Agregar favorito' : 'Editar favorito',
      currentValue: existing?.location,
      type: SavedPlaceType.favorite,
    );

    if (location == null || !mounted) return;

    final savedName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SavedPlaceNameScreen(
          address: location.address,
          initialName: existing?.name ?? location.displayName,
          title: 'Cual es su nombre?',
        ),
      ),
    );

    if (savedName == null || savedName.trim().isEmpty) return;

    await _savePlace(
      type: SavedPlaceType.favorite,
      location: location,
      existing: existing,
      savedName: savedName,
    );
  }

  Future<SimpleLocation?> _pickLocation({
    required String title,
    required SavedPlaceType type,
    SimpleLocation? currentValue,
  }) {
    final icon = switch (type) {
      SavedPlaceType.home => Icons.home_rounded,
      SavedPlaceType.work => Icons.work_rounded,
      SavedPlaceType.favorite => Icons.star_rounded,
    };

    final accentColor = Theme.of(context).colorScheme.primary;

    return showLocationSearchSheet(
      context: context,
      title: title,
      icon: icon,
      accentColor: accentColor,
      currentValue: currentValue,
      suggestionService: _suggestionService,
    );
  }

  Future<void> _savePlace({
    required SavedPlaceType type,
    required SimpleLocation location,
    SavedUserPlace? existing,
    String? savedName,
  }) async {
    setState(() => _isBusy = true);
    try {
      await SavedPlacesService.savePlace(
        type: type,
        location: location,
        placeId: existing?.id,
        savedName: savedName,
      );
      await _loadSavedPlaces(forceRefresh: true);
      if (!mounted) return;

      _showMessage(
        type == SavedPlaceType.favorite
            ? 'Favorito guardado correctamente'
            : 'Direccion guardada correctamente',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('No pudimos guardar la direccion', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _deletePlace(SavedUserPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Eliminar direccion'),
          content: Text(
            place.isFavorite
                ? 'Se eliminara ${place.name} de tus favoritos.'
                : 'Se eliminara tu direccion de ${place.type == SavedPlaceType.home ? 'casa' : 'trabajo'}.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await SavedPlacesService.deletePlace(
        type: place.type,
        placeId: place.isFavorite ? place.id : null,
      );
      await _loadSavedPlaces(forceRefresh: true);
      if (!mounted) return;

      _showMessage('Direccion eliminada correctamente');
    } catch (e) {
      if (!mounted) return;
      _showMessage('No pudimos eliminar la direccion', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: const Text('Mis direcciones'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading || _isBusy ? null : () => _handleFavoriteTap(),
        child: const Icon(Icons.add_rounded),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadSavedPlaces(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                children: [
                  Text(
                    'Accesos rapidos',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildShortcutCard(
                    context,
                    type: SavedPlaceType.home,
                    place: _savedPlaces.home,
                    emptyLabel: 'Agrega tu direccion de casa',
                    onTap: () => _handleHomeOrWorkTap(SavedPlaceType.home),
                  ),
                  const SizedBox(height: 12),
                  _buildShortcutCard(
                    context,
                    type: SavedPlaceType.work,
                    place: _savedPlaces.work,
                    emptyLabel: 'Agrega tu direccion de trabajo',
                    onTap: () => _handleHomeOrWorkTap(SavedPlaceType.work),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Favoritos',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_savedPlaces.favorites.isEmpty)
                    _buildEmptyFavorites(context)
                  else
                    ..._savedPlaces.favorites.map(
                      (place) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildFavoriteCard(context, place),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildShortcutCard(
    BuildContext context, {
    required SavedPlaceType type,
    required SavedUserPlace? place,
    required String emptyLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final icon = switch (type) {
      SavedPlaceType.home => Icons.home_rounded,
      SavedPlaceType.work => Icons.work_rounded,
      SavedPlaceType.favorite => Icons.star_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place?.location.address ?? emptyLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: place == null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (place != null)
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: _isBusy ? null : () => _deletePlace(place),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFavorites(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 48,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavia no tienes favoritos',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tus lugares frecuentes para elegirlos mas rapido al pedir un viaje.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isBusy ? null : () => _handleFavoriteTap(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar lugar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, SavedUserPlace place) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleFavoriteTap(place),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.place_rounded, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.location.address,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: _isBusy ? null : () => _deletePlace(place),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
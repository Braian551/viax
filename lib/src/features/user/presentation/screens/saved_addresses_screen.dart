import 'package:flutter/material.dart';
import 'package:viax/src/features/user/data/models/saved_user_place.dart';
import 'package:viax/src/features/user/presentation/screens/saved_place_name_screen.dart';
import 'package:viax/src/features/user/presentation/widgets/destination/location_search_sheet.dart';
import 'package:viax/src/features/user/services/saved_places_service.dart';
import 'package:viax/src/global/models/simple_location.dart';
import 'package:viax/src/global/services/location_suggestion_service.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final LocationSuggestionService _suggestionService =
      LocationSuggestionService();

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
        elevation: 0,
        centerTitle: true,
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                children: [
                  _SectionLabel(text: 'Accesos rapidos', textTheme: textTheme),
                  const SizedBox(height: 10),
                  _AddressSection(
                    children: [
                      _buildShortcutTile(
                        context,
                        type: SavedPlaceType.home,
                        place: _savedPlaces.home,
                        emptyLabel: 'Agrega tu direccion de casa',
                        onTap: () => _handleHomeOrWorkTap(SavedPlaceType.home),
                      ),
                      _SectionDivider(colorScheme: colorScheme),
                      _buildShortcutTile(
                        context,
                        type: SavedPlaceType.work,
                        place: _savedPlaces.work,
                        emptyLabel: 'Agrega tu direccion de trabajo',
                        onTap: () => _handleHomeOrWorkTap(SavedPlaceType.work),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _SectionLabel(text: 'Favoritos', textTheme: textTheme),
                  const SizedBox(height: 10),
                  if (_savedPlaces.favorites.isEmpty)
                    _buildEmptyFavorites(context)
                  else ...[
                    _AddressSection(
                      children: List.generate(
                        _savedPlaces.favorites.length * 2 - 1,
                        (index) {
                          if (index.isOdd) {
                            return _SectionDivider(colorScheme: colorScheme);
                          }

                          final place = _savedPlaces.favorites[index ~/ 2];
                          return _buildFavoriteTile(context, place);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isBusy ? null : () => _handleFavoriteTap(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar favorito'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildShortcutTile(
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              _SavedAddressIcon(icon: icon),
              const SizedBox(width: 12),
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
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (place != null)
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: _isBusy ? null : () => _deletePlace(place),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                    size: 20,
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
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _savedAddressBorderColor(colorScheme),
          width: 0.8,
        ),
        boxShadow: _savedAddressSectionShadow(colorScheme),
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
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tus lugares frecuentes para elegirlos mas rapido al pedir un viaje.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
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

  Widget _buildFavoriteTile(BuildContext context, SavedUserPlace place) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleFavoriteTap(place),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const _SavedAddressIcon(icon: Icons.star_rounded),
              const SizedBox(width: 12),
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
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: _isBusy ? null : () => _deletePlace(place),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                  size: 20,
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final TextTheme textTheme;

  const _SectionLabel({required this.text, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      text,
      style: textTheme.titleSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  final List<Widget> children;

  const _AddressSection({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _savedAddressBorderColor(colorScheme),
          width: 0.8,
        ),
        boxShadow: _savedAddressSectionShadow(colorScheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SectionDivider({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 68,
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.outlineVariant.withValues(alpha: 0.30)
          : colorScheme.primary.withValues(alpha: 0.08),
    );
  }
}

class _SavedAddressIcon extends StatelessWidget {
  final IconData icon;

  const _SavedAddressIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: colorScheme.primary, size: 21),
    );
  }
}

Color _savedAddressBorderColor(ColorScheme colorScheme) {
  if (colorScheme.brightness == Brightness.dark) {
    return colorScheme.outlineVariant.withValues(alpha: 0.32);
  }

  return colorScheme.primary.withValues(alpha: 0.14);
}

List<BoxShadow> _savedAddressSectionShadow(ColorScheme colorScheme) {
  if (colorScheme.brightness == Brightness.dark) {
    return const [];
  }

  return [
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
}

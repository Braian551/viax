import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

typedef RetryableMapBuilder = Widget Function({
  required Key mapKey,
  required VoidCallback onMapReady,
  required void Function(Object error, [StackTrace? stackTrace]) onTileError,
});

class MapRetryWrapper extends StatefulWidget {
  final RetryableMapBuilder builder;
  final bool isDark;
  final Duration timeout;
  final int maxTileErrors;
  final String title;
  final String subtitle;
  final Future<void> Function()? onRetry;

  const MapRetryWrapper({
    super.key,
    required this.builder,
    required this.isDark,
    this.timeout = const Duration(seconds: 10),
    this.maxTileErrors = 3,
    this.title = 'No se pudo cargar el mapa',
    this.subtitle = 'Puede ser un fallo temporal del SDK o de la conexión.',
    this.onRetry,
  });

  @override
  State<MapRetryWrapper> createState() => _MapRetryWrapperState();
}

class _MapRetryWrapperState extends State<MapRetryWrapper> {
  Timer? _timeoutTimer;
  bool _isMapReady = false;
  bool _hasMapLoadError = false;
  bool _isRetrying = false;
  int _tileLoadErrors = 0;
  Key _mapWidgetKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _startWatchdog();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startWatchdog() {
    _timeoutTimer?.cancel();
    _isMapReady = false;

    _timeoutTimer = Timer(widget.timeout, () {
      if (!mounted) return;
      if (!_isMapReady) {
        setState(() => _hasMapLoadError = true);
      }
    });
  }

  void _handleMapReady() {
    if (!mounted) return;

    _timeoutTimer?.cancel();
    setState(() {
      _isMapReady = true;
      _tileLoadErrors = 0;
      _hasMapLoadError = false;
    });
  }

  void _handleTileError(Object error, [StackTrace? stackTrace]) {
    debugPrint('Map tile error: $error');
    if (!mounted || _hasMapLoadError) return;

    _tileLoadErrors++;
    if (_tileLoadErrors >= widget.maxTileErrors) {
      setState(() => _hasMapLoadError = true);
    }
  }

  Future<void> _retry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
      _isMapReady = false;
      _hasMapLoadError = false;
      _tileLoadErrors = 0;
      _mapWidgetKey = UniqueKey();
    });

    if (widget.onRetry != null) {
      await widget.onRetry!();
    }

    _startWatchdog();

    if (!mounted) return;
    setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasMapLoadError) {
      return Container(
        color: widget.isDark ? AppColors.darkBackground : AppColors.lightBackground,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 44,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _retry,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(_isRetrying ? 'Reintentando...' : 'Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widget.builder(
      mapKey: _mapWidgetKey,
      onMapReady: _handleMapReady,
      onTileError: _handleTileError,
    );
  }
}

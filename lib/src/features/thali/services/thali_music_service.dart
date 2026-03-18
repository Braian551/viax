import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Manages background music playback for the Thali love module
class ThaliMusicService {
  ThaliMusicService._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;

  static const String _musicAsset =
      'sounds/music/System Of A Down - Lonely Day (Official HD Video) - systemofadownVEVO.mp3';

  static bool get isPlaying => _isPlaying;

  static Future<void> play() async {
    try {
      if (_isPlaying) return;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.5);
      await _player.play(AssetSource(_musicAsset));
      _isPlaying = true;
    } catch (e) {
      debugPrint('ThaliMusicService.play error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('ThaliMusicService.stop error: $e');
    }
  }

  static Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  static Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}

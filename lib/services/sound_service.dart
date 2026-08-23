import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameSound { correct, wrong, tick, start }

/// Plays short sound effects bundled in assets/sfx/, and a looping
/// background track from assets/music/. Both volumes are user-adjustable
/// from the settings screen and persisted across launches.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _musicAsset = 'music/Quiz Loop.mp3';
  static const _musicVolumeKey = 'music_volume';
  static const _sfxVolumeKey = 'sfx_volume';

  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'sfx');
  final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'music');
  bool _musicStarted = false;

  double musicVolume = 0.4;
  double sfxVolume = 1.0;

  static const _assetForSound = {
    GameSound.correct: 'sfx/correct.wav',
    GameSound.wrong: 'sfx/wrong.wav',
    GameSound.tick: 'sfx/tick.wav',
    GameSound.start: 'sfx/start.wav',
  };

  /// Restores saved volumes. Call once, before the first sound plays.
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      musicVolume = prefs.getDouble(_musicVolumeKey) ?? musicVolume;
      sfxVolume = prefs.getDouble(_sfxVolumeKey) ?? sfxVolume;
    } catch (_) {
      // Keep the defaults if preferences aren't available for some reason.
    }
  }

  Future<void> setMusicVolume(double volume) async {
    musicVolume = volume;
    try {
      await _musicPlayer.setVolume(volume);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_musicVolumeKey, volume);
    } catch (_) {}
  }

  Future<void> setSfxVolume(double volume) async {
    sfxVolume = volume;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_sfxVolumeKey, volume);
    } catch (_) {}
  }

  Future<void> play(GameSound sound) async {
    if (sfxVolume <= 0) return;
    try {
      await _sfxPlayer.play(
        AssetSource(_assetForSound[sound]!),
        volume: sfxVolume,
      );
    } catch (_) {
      // Best-effort: a missing/broken audio asset shouldn't crash the game.
    }
  }

  Future<void> startMusic() async {
    if (_musicStarted) return;
    _musicStarted = true;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(AssetSource(_musicAsset), volume: musicVolume);
    } catch (_) {
      // No music bundled yet — silently skip until a track is added.
    }
  }

  Future<void> stopMusic() async {
    _musicStarted = false;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }
}

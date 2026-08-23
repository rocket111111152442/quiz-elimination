import 'package:audioplayers/audioplayers.dart';

enum GameSound { correct, wrong, tick, start }

/// Plays short sound effects bundled in assets/sfx/. Also exposes a slot
/// for a looping background track (e.g. a Suno export dropped at
/// assets/music/theme.mp3) that fails silently if no track is present.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'sfx');
  final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'music');
  bool _musicStarted = false;

  static const _assetForSound = {
    GameSound.correct: 'sfx/correct.wav',
    GameSound.wrong: 'sfx/wrong.wav',
    GameSound.tick: 'sfx/tick.wav',
    GameSound.start: 'sfx/start.wav',
  };

  Future<void> play(GameSound sound) async {
    try {
      await _sfxPlayer.play(AssetSource(_assetForSound[sound]!));
    } catch (_) {
      // Best-effort: a missing/broken audio asset shouldn't crash the game.
    }
  }

  Future<void> startMusic() async {
    if (_musicStarted) return;
    _musicStarted = true;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(AssetSource('music/theme.mp3'), volume: 0.4);
    } catch (_) {
      // No music/theme.mp3 bundled yet — silently skip until one is added.
    }
  }

  Future<void> stopMusic() async {
    _musicStarted = false;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }
}

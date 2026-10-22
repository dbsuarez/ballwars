import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../offline/offline_store.dart';

/// The game's 8-bit sounds (assets/sounds, made by tool/sounds/make_sounds.py):
/// button clicks, wall bounces, ball hits, the knock-out, the winner jingle
/// and the background loop during matches. In slow motion the hits switch to
/// slowed, muffled versions and the music slows and quiets down.
///
/// Off until [enabled] is set (main does; tests have no audio plugin). The
/// player's [musicOn] and [effectsOn] choices are saved on the device.
class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  bool enabled = false;
  bool _musicOn = true;
  bool _effectsOn = true;

  static const String _musicKey = 'pref:music';
  static const String _effectsKey = 'pref:sfx';
  static const double _musicVolume = 0.3;

  final Map<String, _Voices> _voices = {};
  AudioPlayer? _music;
  bool _musicWanted = false; // A match is on screen.
  bool _slow = false;
  final Map<String, DateTime> _lastPlayed = {};

  bool get musicOn => _musicOn;

  bool get effectsOn => _effectsOn;

  bool get _playEffects => enabled && _effectsOn;

  bool get _playMusic => enabled && _musicOn;

  /// Loads the saved choices, and lets the sounds mix with each other (and with
  /// other apps) instead of taking audio focus from one another on Android.
  Future<void> init() async {
    try {
      _musicOn = await _readFlag(_musicKey);
      _effectsOn = await _readFlag(_effectsKey);
      if (enabled) {
        await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
        );
      }
    } catch (e) {
      debugPrint('GameAudio: $e');
    }
  }

  Future<void> setMusicOn(bool on) async {
    _musicOn = on;
    if (!_playMusic) {
      _guard(() async => _music?.pause());
    } else if (_musicWanted) {
      _startMusic();
    }
    await _writeFlag(_musicKey, on);
  }

  Future<void> setEffectsOn(bool on) async {
    _effectsOn = on;
    await _writeFlag(_effectsKey, on);
  }

  static Future<bool> _readFlag(String key) async {
    final saved = await OfflineStore.instance.read(key);
    return saved == null || utf8.decode(saved) != 'false';
  }

  static Future<void> _writeFlag(String key, bool on) async {
    try {
      await OfflineStore.instance.write(key, utf8.encode('$on'));
    } catch (_) {}
  }

  void click() => _play('click', 0.6);

  /// A ball hit the rim. Rapid repeats are thinned out.
  void bounce() => _play(_slow ? 'bounce_slow' : 'bounce', 0.45, gap: 70);

  /// Two balls hit each other.
  void collide() => _play(_slow ? 'collide_slow' : 'collide', 0.6, gap: 60);

  /// The runner-up shown knocked out.
  void out() => _play('out', 0.7);

  void win() => _play('win', 0.85);

  /// Starts the loop from the beginning (a new match or round).
  void startMusic() {
    _musicWanted = true;
    if (_playMusic) _startMusic(restart: true);
  }

  void pauseMusic() => _guard(() async => _music?.pause());

  void resumeMusic() {
    if (_playMusic && _musicWanted) _guard(() async => _music?.resume());
  }

  void stopMusic() {
    _musicWanted = false;
    slowMotion = false;
    _guard(() async => _music?.stop());
  }

  set slowMotion(bool slow) {
    if (slow == _slow) return;
    _slow = slow;
    final music = _music;
    if (music == null) return;
    _guard(() async {
      await music.setPlaybackRate(slow ? 0.8 : 1.0);
      await music.setVolume(slow ? _musicVolume * 0.45 : _musicVolume);
    });
  }

  void _startMusic({bool restart = false}) {
    _guard(() async {
      final music = _music ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      if (!restart && music.state == PlayerState.paused) {
        await music.resume();
        return;
      }
      await music.setVolume(_slow ? _musicVolume * 0.45 : _musicVolume);
      await music.play(AssetSource('sounds/bgm.wav'));
    });
  }

  void _play(String name, double volume, {int gap = 0}) {
    if (!_playEffects) return;
    if (gap > 0) {
      final now = DateTime.now();
      final last = _lastPlayed[name];
      if (last != null && now.difference(last).inMilliseconds < gap) return;
      _lastPlayed[name] = now;
    }
    _voices.putIfAbsent(name, () => _Voices(name)).play(volume);
  }

  static void _guard(Future<void> Function() action) {
    unawaited(action().catchError((Object e) => debugPrint('GameAudio: $e')));
  }
}

/// A few players for one sound, used in turn so quick repeats can overlap.
class _Voices {
  final String name;
  final List<AudioPlayer> _players = [];
  int _next = 0;

  static const int _count = 3;

  _Voices(this.name);

  void play(double volume) {
    if (_players.length < _count) _players.add(AudioPlayer());
    final player = _players[_next++ % _players.length];
    GameAudio._guard(() => player.play(AssetSource('sounds/$name.wav'), volume: volume, mode: PlayerMode.lowLatency));
  }
}

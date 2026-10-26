import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import '../offline/offline_store.dart';

/// A background track: match music (`assets/sounds/bgm_<id>.wav`) or Home
/// screen music (`menu_<id>.wav`), composed in tool/sounds/music.py. The
/// admin picks one of each for everyone.
class MusicTrack {
  final String id;
  final String name;
  final String mood;
  final String _file;

  const MusicTrack(this.id, this.name, this.mood) : _file = 'bgm_$id';

  const MusicTrack.home(this.id, this.name, this.mood) : _file = 'menu_$id';

  String get asset => 'sounds/$_file.wav';

  /// Match music.
  static const List<MusicTrack> all = [
    MusicTrack('arena', 'Arena', 'The classic theme · A minor, 140 bpm'),
    MusicTrack('turbo', 'Turbo', 'Fast and driving · 168 bpm'),
    MusicTrack('sunny', 'Sunny Day', 'Bouncy and bright · C major'),
    MusicTrack('boss', 'Boss Fight', 'Tense, dark and heavy'),
    MusicTrack('chill', 'Chill Out', 'Laid back · 96 bpm'),
  ];

  /// Home screen music: slow and soft.
  static const List<MusicTrack> menu = [
    MusicTrack.home('drift', 'Drift', 'Calm and open · 66 bpm'),
    MusicTrack.home('lantern', 'Lantern', 'Wistful · A minor, 70 bpm'),
    MusicTrack.home('tide', 'Tide', 'Rolling and soft · 60 bpm'),
    MusicTrack.home('hearth', 'Hearth', 'Warm · F major, 72 bpm'),
    MusicTrack.home('starlight', 'Starlight', 'Dreamy and sparse · 64 bpm'),
  ];

  static MusicTrack byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static MusicTrack menuById(String id) =>
      menu.firstWhere((t) => t.id == id, orElse: () => menu.first);
}

/// The game's 8-bit sounds (assets/sounds, made by tool/sounds/make_sounds.py):
/// button clicks, wall bounces, ball hits, the knock-out, the winner jingle,
/// the background loop during matches, and the Home screen music everywhere
/// outside matches. In slow motion the hits switch to slowed, muffled
/// versions and the match music slows and quiets down. Music pauses while
/// the app is in the background (phone locked).
///
/// Off until [enabled] is set (main does; tests have no audio plugin). The
/// player's [musicOn], [menuMusicOn] and [effectsOn] choices are saved on the
/// device.
class GameAudio with WidgetsBindingObserver {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  bool enabled = false;
  bool _musicOn = true;
  int _musicEpoch = 0;
  bool _menuMusicOn = true;
  bool _effectsOn = true;

  static const String _musicKey = 'pref:music';
  static const String _menuMusicKey = 'pref:menu-music';
  static const String _effectsKey = 'pref:sfx';
  static const double _musicVolume = 0.3;
  static const double _menuVolume = 0.35;

  final Map<String, _Voices> _voices = {};
  AudioPlayer? _music;
  AudioPlayer? _menu;
  AudioPlayer? _preview;
  String? _previewing;
  MusicTrack _track = MusicTrack.all.first;
  MusicTrack _menuTrack = MusicTrack.menu.first;
  bool _musicWanted = false; // A match is on screen.
  bool _musicPausedByUser = false; // The match is paused.
  bool _menuWanted = false; // Outside a match.
  bool _foreground = true;
  bool _slow = false;
  final Map<String, int> _lastPlayed = {};
  final Stopwatch _effectClock = Stopwatch()..start();
  Future<void> _musicQueue = Future.value();
  Future<void> _menuQueue = Future.value();
  int _menuEpoch = 0;

  @visibleForTesting
  static AudioPlayer Function()? playerFactory;

  bool get musicOn => _musicOn;

  bool get menuMusicOn => _menuMusicOn;

  bool get effectsOn => _effectsOn;

  MusicTrack get track => _track;

  /// The match music (from the admin's setting); a playing loop switches.
  set track(MusicTrack track) {
    if (track.id == _track.id) return;
    _track = track;
    if (_playMusic && _musicWanted && _music?.state == PlayerState.playing) {
      _startMusic(restart: true);
    }
  }

  MusicTrack get menuTrack => _menuTrack;

  /// The Home music (from the admin's setting); a playing loop switches.
  set menuTrack(MusicTrack track) {
    if (track.id == _menuTrack.id) return;
    _menuTrack = track;
    if (_menu?.state == PlayerState.playing) _startMenu(restart: true);
  }

  bool get _playEffects => enabled && _effectsOn && _foreground;

  bool get _playMusic => enabled && _musicOn && _foreground;

  bool get _playMenu =>
      enabled && _menuMusicOn && _foreground && _previewing == null;

  /// Loads the saved choices, and lets the sounds mix with each other (and with
  /// other apps) instead of taking audio focus from one another on Android.
  Future<void> init() async {
    try {
      _musicOn = await _readFlag(_musicKey);
      _menuMusicOn = await _readFlag(_menuMusicKey);
      _effectsOn = await _readFlag(_effectsKey);
      if (enabled) {
        WidgetsBinding.instance.addObserver(this);
        await AudioPlayer.global.setAudioContext(
          AudioContextConfig(
            focus: AudioContextConfigFocus.mixWithOthers,
          ).build(),
        );
      }
    } catch (e) {
      debugPrint('GameAudio: $e');
    }
  }

  /// Locked phone / app in the background: all music pauses; on return only
  /// what should be playing resumes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      resetEffects();
      if (_playMusic && _musicWanted && !_musicPausedByUser) _startMusic();
      if (_playMenu && _menuWanted) _startMenu();
    } else {
      _foreground = false;
      _musicEpoch++;
      _menuEpoch++;
      resetEffects();
      _queueMusic(() async => _music?.pause());
      _queueMenu(() async => _menu?.pause());
      stopPreview();
    }
  }

  Future<void> setMusicOn(bool on) async {
    _musicOn = on;
    if (!_playMusic) {
      _musicEpoch++;
      _queueMusic(() async => _music?.pause());
    } else if (_musicWanted && !_musicPausedByUser) {
      _startMusic();
    }
    await _writeFlag(_musicKey, on);
  }

  Future<void> setMenuMusicOn(bool on) async {
    _menuMusicOn = on;
    if (!_playMenu) {
      _menuEpoch++;
      _queueMenu(() async => _menu?.pause());
    } else if (_menuWanted) {
      _startMenu();
    }
    await _writeFlag(_menuMusicKey, on);
  }

  Future<void> setEffectsOn(bool on) async {
    _effectsOn = on;
    resetEffects();
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

  /// A tap. Browsers only allow sound after the user interacts with the
  /// page, so a Home music that couldn't start at launch starts here.
  void click() {
    _play('click', 0.6);
    if (_playMenu && _menuWanted && _menu?.state != PlayerState.playing) {
      _startMenu();
    }
  }

  /// A ball hit the rim. Rapid repeats are thinned out.
  void bounce() => _play(_slow ? 'bounce_slow' : 'bounce', 0.45, gap: 70);

  /// Two balls hit each other.
  void collide() => _play(_slow ? 'collide_slow' : 'collide', 0.6, gap: 60);

  /// The runner-up shown knocked out.
  void out() => _play('out', 0.7);

  void win() => _play('win', 0.85);

  void whistle() => _play('whistle', 0.8);

  /// Start each match with fresh players; native players can lose their
  /// reusable sound handle after completion or an audio focus interruption.
  void resetEffects() {
    final old = _voices.values.toList();
    _voices.clear();
    _lastPlayed.clear();
    for (final voices in old) {
      voices.dispose();
    }
  }

  // Power-ups (Arsenal / All-Out). Rapid repeats (gatling, pellets) are thinned out.
  void shot() => _play('shot', 0.45, gap: 50);

  void shotgun() => _play('shotgun', 0.6, gap: 120);

  void gatling() => _play('gatling', 0.5, gap: 60);

  void slash() => _play('slash', 0.55, gap: 80);

  void shield() => _play('shield', 0.5, gap: 120);

  void bomb() => _play('bomb', 0.75, gap: 150);

  void pickup() => _play('pickup', 0.5, gap: 80);

  void hit() => _play('hit', 0.5, gap: 60);

  /// Plays one of the curated cues exposed by Skill Management.
  void skillCue(String cue) {
    if (const {
      'shot',
      'shotgun',
      'gatling',
      'slash',
      'shield',
      'bomb',
      'pickup',
      'hit',
    }.contains(cue)) {
      _play(cue, 0.6, gap: 60);
    }
  }

  /// Plays a curated skill cue from an explicit admin preview action.
  /// Previewing intentionally ignores the SFX preference: the administrator
  /// must be able to audition a cue before deciding whether to enable sounds.
  void previewSkillCue(String cue) {
    if (!enabled || !_foreground) return;
    if (const {
      'shot',
      'shotgun',
      'gatling',
      'slash',
      'shield',
      'bomb',
      'pickup',
      'hit',
    }.contains(cue)) {
      _voices.putIfAbsent(cue, () => _Voices(cue)).play(0.8);
    }
  }

  /// Existing sounds mapped to otherwise silent interactions.
  void interaction(String event) {
    switch (event) {
      case 'warp':
        pickup();
      case 'freeze':
      case 'repel':
        shield();
      case 'trap':
        hit();
      case 'cut':
        slash();
      case 'out':
        out();
    }
  }

  // --- Home music (everywhere outside matches) -------------------------------

  /// Outside a match (app start, back from a match).
  void startMenuMusic() {
    _menuWanted = true;
    if (_playMenu) _startMenu();
  }

  /// A match starts: Home music steps aside for the match music.
  void stopMenuMusic() {
    _menuWanted = false;
    _menuEpoch++;
    _queueMenu(() async => _menu?.pause());
  }

  void _startMenu({bool restart = false}) {
    final epoch = ++_menuEpoch;
    _queueMenu(() async {
      bool wanted() => epoch == _menuEpoch && _playMenu && _menuWanted;
      if (!wanted()) return;
      final menu = _menu ??= _newPlayer();
      await menu.setReleaseMode(ReleaseMode.loop);
      if (!wanted()) return;
      if (!restart && menu.state == PlayerState.paused) {
        await menu.resume();
        return;
      }
      await menu.setVolume(_menuVolume);
      if (!wanted()) return;
      await menu.play(AssetSource(_menuTrack.asset));
      if (!_playMenu || !_menuWanted) await menu.pause();
    });
  }

  // --- Match music ------------------------------------------------------------

  /// Starts the loop from the beginning (a new match or round).
  void startMusic() {
    _musicWanted = true;
    _musicPausedByUser = false;
    if (_playMusic) _startMusic(restart: true);
  }

  /// The match is paused.
  void pauseMusic() {
    _musicEpoch++;
    _musicPausedByUser = true;
    _queueMusic(() async => _music?.pause());
  }

  void resumeMusic() {
    _musicPausedByUser = false;
    if (_playMusic && _musicWanted) _startMusic();
  }

  void stopMusic() {
    _musicEpoch++;
    _musicWanted = false;
    slowMotion = false;
    _queueMusic(() async => _music?.stop());
  }

  set slowMotion(bool slow) {
    if (slow == _slow) return;
    _slow = slow;
    final music = _music;
    if (music == null) return;
    _queueMusic(() async {
      await music.setPlaybackRate(slow ? 0.8 : 1.0);
      await music.setVolume(slow ? _musicVolume * 0.45 : _musicVolume);
    });
  }

  void _startMusic({bool restart = false}) {
    final epoch = ++_musicEpoch;
    _queueMusic(() async {
      bool wanted() =>
          epoch == _musicEpoch &&
          _playMusic &&
          _musicWanted &&
          !_musicPausedByUser;
      if (!wanted()) return;
      final music = _music ??= _newPlayer();
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setPlaybackRate(_slow ? 0.8 : 1.0);
      await music.setVolume(_slow ? _musicVolume * 0.45 : _musicVolume);
      if (!wanted()) return;
      if (!restart && music.state == PlayerState.paused) {
        await music.resume();
      } else {
        await music.play(
          AssetSource(_track.asset),
          volume: _slow ? _musicVolume * 0.45 : _musicVolume,
        );
      }
      if (!wanted() && (!_playMusic || !_musicWanted || _musicPausedByUser)) {
        await music.pause();
      }
    });
  }

  // --- Admin previews ---------------------------------------------------------

  /// The track [id] being previewed, if any.
  String? get previewing => _previewing;

  /// Plays [track] once for the admin's track pickers, whatever the music
  /// switches say (the Home music pauses meanwhile); [onDone] runs when it
  /// stops by itself.
  void preview(MusicTrack track, {VoidCallback? onDone}) {
    if (!enabled) return;
    _previewing = track.asset;
    _queueMenu(() async => _menu?.pause());
    _guard(() async {
      final player = _preview ??= _newPlayer();
      await player.stop();
      await player
          .setReleaseMode(ReleaseMode.stop)
          .timeout(const Duration(seconds: 3));
      await player.play(AssetSource(track.asset), volume: 0.6);
      await player.onPlayerComplete.first;
      if (_previewing == track.asset) {
        _endPreview();
        onDone?.call();
      }
    });
  }

  /// Whether [track] is the one being previewed.
  bool isPreviewing(MusicTrack track) => _previewing == track.asset;

  void stopPreview() {
    if (_previewing == null) return;
    _guard(() async => _preview?.stop());
    _endPreview();
  }

  void _endPreview() {
    _previewing = null;
    if (_playMenu && _menuWanted) _startMenu();
  }

  void _play(String name, double volume, {int gap = 0}) {
    if (!_playEffects) return;
    if (gap > 0) {
      final now = _effectClock.elapsedMilliseconds;
      final last = _lastPlayed[name];
      if (last != null && now - last < gap) return;
      _lastPlayed[name] = now;
    }
    _voices.putIfAbsent(name, () => _Voices(name)).play(volume);
  }

  /// A player without position updates. By default audioplayers polls the playback position on every
  /// frame while a player plays (FramePositionUpdater): it keeps the app drawing at the screen's full rate
  /// (120 Hz) even on still screens and sends a platform call per frame, which on Android runs on the
  /// same thread as the app and made every screen slow while music played. Nothing here reads positions.
  static AudioPlayer _newPlayer() =>
      playerFactory?.call() ?? (AudioPlayer()..positionUpdater = null);

  void _queueMenu(Future<void> Function() action) {
    _menuQueue = _menuQueue
        .then((_) => action().timeout(const Duration(seconds: 4)))
        .catchError((Object e) {
          debugPrint('GameAudio menu: $e');
          final failed = _menu;
          _menu = null;
          if (failed != null) _guard(failed.dispose);
        });
  }

  void _queueMusic(Future<void> Function() action) {
    _musicQueue = _musicQueue
        .then((_) => action().timeout(const Duration(seconds: 4)))
        .catchError((Object e) {
          debugPrint('GameAudio music: $e');
          final failed = _music;
          _music = null;
          if (failed != null) _guard(failed.dispose);
        });
  }

  static void _guard(Future<void> Function() action) {
    unawaited(action().catchError((Object e) => debugPrint('GameAudio: $e')));
  }
}

/// A few players for one sound, used in turn so quick repeats can overlap.
class _Voices {
  final String name;
  final List<AudioPlayer> _players = [];
  final Set<AudioPlayer> _busy = {};
  bool _disposed = false;
  int _next = 0;
  static const int _count = 3;

  _Voices(this.name);

  void play(double volume) {
    if (_disposed) return;
    if (_players.length < _count) _players.add(GameAudio._newPlayer());
    AudioPlayer? available;
    for (var i = 0; i < _players.length; i++) {
      final candidate = _players[_next++ % _players.length];
      if (!_busy.contains(candidate)) {
        available = candidate;
        break;
      }
    }
    if (available == null) {
      return; // Never issue overlapping commands to a player.
    }
    final player = available;
    _busy.add(player);
    GameAudio._guard(() async {
      try {
        // Keep reusable media players on both platforms. Low-latency native
        // sound handles have gone silent after repeated match/restart cycles.
        await player
            .setReleaseMode(ReleaseMode.stop)
            .timeout(const Duration(seconds: 3));
        if (_disposed) return;
        await player
            .play(
              AssetSource('sounds/$name.wav'),
              volume: volume,
              mode: PlayerMode.mediaPlayer,
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        _players.remove(player);
        try {
          await player.dispose();
        } catch (_) {}
        rethrow; // Logged; the next event gets a new player instead of a dead one.
      } finally {
        _busy.remove(player);
        if (_disposed) {
          try {
            await player.dispose();
          } catch (_) {}
        }
      }
    });
  }

  void dispose() {
    _disposed = true;
    for (final player in _players.where((p) => !_busy.contains(p)).toList()) {
      GameAudio._guard(player.dispose);
    }
    _players.clear();
  }
}

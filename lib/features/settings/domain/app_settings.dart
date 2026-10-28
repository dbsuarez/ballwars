import 'dart:ui';

import '../../arena_simulation/domain/power_up_config.dart';
import '../../skills/domain/skill_library.dart';

enum ArenaDecoration {
  defaultArena('Default'),
  space('Space'),
  desert('Desert'),
  wilderness('Wilderness'),
  neonGrid('Neon Grid'),
  chaotic('Chaotic');

  const ArenaDecoration(this.label);
  final String label;

  /// The hazard this arena adds, as the arena pickers caption it under [label].
  String get hazardCaption => switch (this) {
    ArenaDecoration.defaultArena => 'Spike Wall',
    ArenaDecoration.space => 'Gravity Well',
    ArenaDecoration.desert => 'Quicksand',
    ArenaDecoration.wilderness => 'Vine Snare',
    ArenaDecoration.neonGrid => 'Laser Gate',
    ArenaDecoration.chaotic => 'All arena traps',
  };
}

enum EffectRenderMode {
  sprite('Sprite'),
  vector('Vector fallback');

  const EffectRenderMode(this.label);
  final String label;
}

/// App-wide settings, set by the admin and shown to everyone
/// (Supabase table `app_settings`, see supabase/migrations/002, 003, 005, 006, 009 and 011).
class AppSettings {
  /// Big title over the arena and in videos, e.g. "WHO WINS?".
  final String headline;

  /// [ThemePreset.id] of the app's theme.
  final String themeId;

  /// The tiled watermark behind the winner card.
  final bool watermarkEnabled;
  final bool ballGlowEnabled;
  final double ballGlowWidth;
  final Color bloodColor;
  final String arenaTitle;
  final String arenaSubtitle;
  final double minimumArenaScale;
  final ArenaDecoration arenaDecoration;
  final EffectRenderMode projectileRenderMode;
  final EffectRenderMode explosionRenderMode;
  final EffectRenderMode freezeRenderMode;
  final String watermarkText;

  /// [MusicTrack.id] of the background music during matches.
  final String musicId;

  /// [MusicTrack.id] of the Home screen music (MusicTrack.menu).
  final String menuMusicId;

  /// Slow motion starts when one of the last two balls is down to this many
  /// lines (0: never)...
  final int slowMotionLines;

  /// ...or, when set, this many seconds of game time before the winning cut
  /// (predicted, see MatchSimulationController.slowMotionBeforeWinSeconds).
  final double? slowMotionBeforeWinSeconds;

  /// The power-up numbers for Arsenal and All-Out matches (only the changed values are stored).
  final PowerUpConfig powerUps;
  final SkillLibrary skillLibrary;

  const AppSettings({
    this.headline = defaultHeadline,
    this.themeId = 'midnight',
    this.watermarkEnabled = true,
    this.ballGlowEnabled = true,
    this.ballGlowWidth = 4,
    this.bloodColor = defaultBloodColor,
    this.arenaTitle = defaultArenaTitle,
    this.arenaSubtitle = defaultArenaSubtitle,
    this.minimumArenaScale = defaultMinimumArenaScale,
    this.arenaDecoration = ArenaDecoration.defaultArena,
    this.projectileRenderMode = EffectRenderMode.sprite,
    this.explosionRenderMode = EffectRenderMode.sprite,
    this.freezeRenderMode = EffectRenderMode.sprite,
    this.watermarkText = defaultWatermark,
    this.musicId = defaultMusic,
    this.menuMusicId = defaultMenuMusic,
    this.slowMotionLines = defaultSlowMotionLines,
    this.slowMotionBeforeWinSeconds,
    this.powerUps = PowerUpConfig.defaults,
    this.skillLibrary = SkillLibrary.defaults,
  });

  static const String defaultHeadline = 'WHO WINS?';
  static const String defaultWatermark = 'dbsuarez';
  static const String defaultMusic = 'arena';
  static const String defaultMenuMusic = 'drift';
  static const int defaultSlowMotionLines = 10;
  static const Color defaultBloodColor = Color(0xFFD9152B);
  static const String defaultArenaTitle = 'dbsuarez';
  static const String defaultArenaSubtitle = 'bakbakan na';
  static const double defaultMinimumArenaScale = 0.60;
  static const double defaultSlowMotionBeforeWinSeconds = 1.5;
  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    String? headline,
    String? themeId,
    bool? watermarkEnabled,
    bool? ballGlowEnabled,
    double? ballGlowWidth,
    Color? bloodColor,
    String? arenaTitle,
    String? arenaSubtitle,
    double? minimumArenaScale,
    ArenaDecoration? arenaDecoration,
    EffectRenderMode? projectileRenderMode,
    EffectRenderMode? explosionRenderMode,
    EffectRenderMode? freezeRenderMode,
    String? watermarkText,
    String? musicId,
    String? menuMusicId,
    int? slowMotionLines,
    double? Function()? slowMotionBeforeWinSeconds,
    PowerUpConfig? powerUps,
    SkillLibrary? skillLibrary,
  }) => AppSettings(
    headline: headline ?? this.headline,
    themeId: themeId ?? this.themeId,
    watermarkEnabled: watermarkEnabled ?? this.watermarkEnabled,
    ballGlowEnabled: ballGlowEnabled ?? this.ballGlowEnabled,
    ballGlowWidth: ballGlowWidth ?? this.ballGlowWidth,
    bloodColor: bloodColor ?? this.bloodColor,
    arenaTitle: arenaTitle ?? this.arenaTitle,
    arenaSubtitle: arenaSubtitle ?? this.arenaSubtitle,
    minimumArenaScale: minimumArenaScale ?? this.minimumArenaScale,
    arenaDecoration: arenaDecoration ?? this.arenaDecoration,
    projectileRenderMode: projectileRenderMode ?? this.projectileRenderMode,
    explosionRenderMode: explosionRenderMode ?? this.explosionRenderMode,
    freezeRenderMode: freezeRenderMode ?? this.freezeRenderMode,
    watermarkText: watermarkText ?? this.watermarkText,
    musicId: musicId ?? this.musicId,
    menuMusicId: menuMusicId ?? this.menuMusicId,
    slowMotionLines: slowMotionLines ?? this.slowMotionLines,
    slowMotionBeforeWinSeconds: slowMotionBeforeWinSeconds == null
        ? this.slowMotionBeforeWinSeconds
        : slowMotionBeforeWinSeconds(),
    powerUps: powerUps ?? this.powerUps,
    skillLibrary: skillLibrary ?? this.skillLibrary,
  );
}

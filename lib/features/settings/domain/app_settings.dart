import '../../arena_simulation/domain/power_up_config.dart';

/// App-wide settings, set by the admin and shown to everyone
/// (Supabase table `app_settings`, see supabase/migrations/002, 003, 005, 006, 009 and 011).
class AppSettings {
  /// Big title over the arena and in videos, e.g. "WHO WINS?".
  final String headline;

  /// [ThemePreset.id] of the app's theme.
  final String themeId;

  /// The tiled watermark behind the winner card.
  final bool watermarkEnabled;
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

  const AppSettings({
    this.headline = defaultHeadline,
    this.themeId = 'midnight',
    this.watermarkEnabled = true,
    this.watermarkText = defaultWatermark,
    this.musicId = defaultMusic,
    this.menuMusicId = defaultMenuMusic,
    this.slowMotionLines = defaultSlowMotionLines,
    this.slowMotionBeforeWinSeconds,
    this.powerUps = PowerUpConfig.defaults,
  });

  static const String defaultHeadline = 'WHO WINS?';
  static const String defaultWatermark = 'dbsuarez';
  static const String defaultMusic = 'arena';
  static const String defaultMenuMusic = 'drift';
  static const int defaultSlowMotionLines = 10;
  static const double defaultSlowMotionBeforeWinSeconds = 1.5;
  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    String? headline,
    String? themeId,
    bool? watermarkEnabled,
    String? watermarkText,
    String? musicId,
    String? menuMusicId,
    int? slowMotionLines,
    double? Function()? slowMotionBeforeWinSeconds,
    PowerUpConfig? powerUps,
  }) =>
      AppSettings(
        headline: headline ?? this.headline,
        themeId: themeId ?? this.themeId,
        watermarkEnabled: watermarkEnabled ?? this.watermarkEnabled,
        watermarkText: watermarkText ?? this.watermarkText,
        musicId: musicId ?? this.musicId,
        menuMusicId: menuMusicId ?? this.menuMusicId,
        slowMotionLines: slowMotionLines ?? this.slowMotionLines,
        slowMotionBeforeWinSeconds:
            slowMotionBeforeWinSeconds == null ? this.slowMotionBeforeWinSeconds : slowMotionBeforeWinSeconds(),
        powerUps: powerUps ?? this.powerUps,
      );
}

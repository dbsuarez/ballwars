/// App-wide settings, set by the admin and shown to everyone
/// (Supabase table `app_settings`, see supabase/migrations/002 and 003).
class AppSettings {
  /// Big title over the arena and in videos, e.g. "WHO WINS?".
  final String headline;

  /// [ThemePreset.id] of the app's theme.
  final String themeId;

  /// The tiled watermark behind the winner card.
  final bool watermarkEnabled;
  final String watermarkText;

  const AppSettings({
    this.headline = defaultHeadline,
    this.themeId = 'midnight',
    this.watermarkEnabled = true,
    this.watermarkText = defaultWatermark,
  });

  static const String defaultHeadline = 'WHO WINS?';
  static const String defaultWatermark = 'dbsuarez';
  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({String? headline, String? themeId, bool? watermarkEnabled, String? watermarkText}) =>
      AppSettings(
        headline: headline ?? this.headline,
        themeId: themeId ?? this.themeId,
        watermarkEnabled: watermarkEnabled ?? this.watermarkEnabled,
        watermarkText: watermarkText ?? this.watermarkText,
      );
}

import '../../settings/domain/app_settings.dart';
import 'match_config.dart';

/// Deterministic arena changes driven by simulation time, not wall-clock time.
/// Both rotations are opt-in and independent.
class ArenaRotation {
  const ArenaRotation({
    this.rotateThemes = false,
    this.rotateShapes = false,
    this.intervalSeconds = 60,
  }) : assert(intervalSeconds >= 30);

  final bool rotateThemes;
  final bool rotateShapes;
  final int intervalSeconds;

  static const List<ArenaDecoration> themes = [
    ArenaDecoration.defaultArena,
    ArenaDecoration.neonGrid,
    ArenaDecoration.desert,
    ArenaDecoration.space,
    ArenaDecoration.wilderness,
  ];

  /// Limit interval to half of a timed match, rounded to a 30-second step.
  /// A timed match shorter than 60 seconds cannot rotate at least once.
  int intervalForMatch({int? matchDurationSeconds}) {
    if (matchDurationSeconds == null) return intervalSeconds;
    final maximum = ((matchDurationSeconds / 2) / 30).round() * 30;
    if (maximum < 30) return intervalSeconds;
    return intervalSeconds.clamp(30, maximum);
  }

  int transitionsAt(double elapsedSeconds, {int? matchDurationSeconds}) {
    if (elapsedSeconds < 0) return 0;
    return elapsedSeconds ~/ intervalForMatch(matchDurationSeconds: matchDurationSeconds);
  }

  ArenaDecoration themeAt(ArenaDecoration initial, double elapsedSeconds,
      {int? matchDurationSeconds}) {
    if (!rotateThemes) return initial;
    final start = themes.indexOf(initial);
    // Chaotic is intentionally never included in automatic rotation.
    final index = start < 0 ? 0 : start;
    return themes[(index + transitionsAt(elapsedSeconds,
        matchDurationSeconds: matchDurationSeconds)) % themes.length];
  }

  ArenaShape shapeAt(ArenaShape initial, double elapsedSeconds,
      {int? matchDurationSeconds}) {
    if (!rotateShapes) return initial;
    return transitionsAt(elapsedSeconds,
        matchDurationSeconds: matchDurationSeconds).isEven
        ? initial
        : (initial == ArenaShape.circle ? ArenaShape.square : ArenaShape.circle);
  }
}

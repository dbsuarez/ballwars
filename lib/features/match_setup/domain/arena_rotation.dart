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
    // There is no valid interval for a match shorter than one minute.
    // Keep the configured interval but do not schedule a transition.
    if (maximum < 30) return intervalSeconds;
    return intervalSeconds.clamp(30, maximum);
  }

  /// Seconds until the next transition. Null when rotation is disabled or
  /// the match is too short to permit a transition.
  double? secondsUntilNext(double elapsedSeconds, {int? matchDurationSeconds}) {
    if ((!rotateThemes && !rotateShapes) ||
        (matchDurationSeconds != null && matchDurationSeconds < 60)) {
      return null;
    }
    final interval = intervalForMatch(matchDurationSeconds: matchDurationSeconds);
    if (matchDurationSeconds != null && elapsedSeconds >= matchDurationSeconds) {
      return null;
    }
    final next = (elapsedSeconds ~/ interval + 1) * interval;
    if (matchDurationSeconds != null && next > matchDurationSeconds) return null;
    return next - elapsedSeconds;
  }

  /// Normalized 0..1 flash progress after the most recent transition.
  /// This is derived from simulation time and does not affect physics.
  double transitionFlash(double elapsedSeconds, {int? matchDurationSeconds}) {
    if ((!rotateThemes && !rotateShapes) ||
        (matchDurationSeconds != null && matchDurationSeconds < 60)) {
      return 0;
    }
    final interval = intervalForMatch(matchDurationSeconds: matchDurationSeconds);
    if (elapsedSeconds < interval) return 0;
    final since = elapsedSeconds % interval;
    return (1 - since / 0.55).clamp(0.0, 1.0);
  }

  int transitionsAt(double elapsedSeconds, {int? matchDurationSeconds}) {
    if (elapsedSeconds < 0 ||
        (matchDurationSeconds != null && matchDurationSeconds < 60)) {
      return 0;
    }
    // Fixed-timestep accumulation can land infinitesimally below a boundary
    // (for example 1800 * (1 / 60) < 30). Tolerate only rounding noise.
    final interval = intervalForMatch(matchDurationSeconds: matchDurationSeconds);
    return ((elapsedSeconds + 1e-9) / interval).floor();
  }

  ArenaDecoration themeAt(ArenaDecoration initial, double elapsedSeconds,
      {int? matchDurationSeconds}) {
    if (!rotateThemes) return initial;
    final transitions = transitionsAt(elapsedSeconds,
        matchDurationSeconds: matchDurationSeconds);
    // A manually selected Chaotic arena stays visible until the first change.
    if (transitions == 0) return initial;
    final start = themes.indexOf(initial);
    // Chaotic is intentionally never included in automatic rotation.
    final index = start < 0 ? 0 : start;
    return themes[(index + transitions) % themes.length];
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

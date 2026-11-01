import 'skill_library.dart';

/// A deterministic, clock-driven trigger component for composed skills.
///
/// The arena owns this scheduler per equipped skill/actor. It does not apply
/// damage or spawn visuals; each returned activation must be dispatched by the
/// arena's effect executor. Time is elapsed match seconds, not wall-clock time.
class SkillTriggerScheduler {
  SkillTriggerScheduler(this.skill) {
    if (skill.trigger == SkillTrigger.timer) {
      _nextTimerAt = _positive(skill.triggerIntervalSeconds);
    }
  }

  final SkillDefinition skill;
  double _readyAt = 0;
  double? _nextTimerAt;
  final List<double> _pending = [];
  static const int maxPendingActivations = 1024;

  int get pendingCount => _pending.length;
  int get pendingActivationCount => _pending.length;

  /// The next timer tick, useful for debugging and deterministic tests.
  double? get nextTimerAt => _nextTimerAt;
  double _lastTime = 0;

  static double _positive(double value) =>
      value.isFinite && value > 0 ? value : 0.001;

  /// Schedules a matching event. Returns false for mismatched events or while
  /// on cooldown. The first activation may be delayed by startDelaySeconds.
  bool signal(SkillTrigger event, double atSeconds) {
    _checkTime(atSeconds);
    if (skill.trigger != event || event == SkillTrigger.timer ||
        atSeconds < _readyAt) {
      return false;
    }
    if (!_schedule(atSeconds)) return false;
    return true;
  }

  /// Returns the due activation timestamps in chronological order. A caller
  /// may advance several frames at once without losing timer or repeat ticks.
  List<double> advance(double toSeconds) {
    _checkTime(toSeconds);
    if (_nextTimerAt != null) {
      final interval = _positive(skill.triggerIntervalSeconds);
      // Limit catch-up to avoid an unbounded loop after a very long pause.
      var count = 0;
      while (_nextTimerAt! <= toSeconds && count < 1024) {
        final at = _nextTimerAt!;
        if (at >= _readyAt && !_schedule(at)) {
          // Keep this timer tick pending until queue space becomes available.
          break;
        }
        final nextTick = at + interval;
        // Floating-point precision can stop advancing at very large match
        // times. Disable an unrepresentable timer instead of looping forever.
        if (!nextTick.isFinite || nextTick <= at) {
          _nextTimerAt = null;
          break;
        }
        _nextTimerAt = nextTick;
        count++;
      }
      if (count == 1024 && _nextTimerAt != null &&
          _nextTimerAt! <= toSeconds) {
        final nextTick = toSeconds + interval;
        _nextTimerAt = nextTick.isFinite && nextTick > toSeconds
            ? nextTick : null;
      }
    }
    _pending.sort();
    final due = <double>[];
    _pending.removeWhere((at) {
      if (at > toSeconds) return false;
      due.add(at);
      return true;
    });
    return List.unmodifiable(due);
  }

  /// Retry one rejected activation on a subsequent simulation frame.
  /// A rejection must not silently consume an event or create an unbounded
  /// retry backlog. The arena owns effect admission and calls this only when
  /// its executor rejected a due activation.
  bool retryRejected(double atSeconds) {
    _checkTime(atSeconds);
    if (_pending.length >= maxPendingActivations) {
      return false;
    }
    final next = atSeconds + 1 / 60;
    if (!next.isFinite || next <= atSeconds) {
      return false;
    }
    // One retry per scheduler is sufficient. Avoid duplicating an existing
    // activation when multiple triggers are rejected in the same frame.
    if (_pending.any((pending) => pending >= atSeconds &&
        pending <= next)) {
      return true;
    }
    _pending.add(next);
    return true;
  }

  void cancelPending() => _pending.clear();

  void reset() {
    _pending.clear();
    _readyAt = 0;
    _lastTime = 0;
    _nextTimerAt = skill.trigger == SkillTrigger.timer
        ? _positive(skill.triggerIntervalSeconds) : null;
  }

  bool _schedule(double at) {
    final delay = skill.startDelaySeconds.isFinite && skill.startDelaySeconds > 0
        ? skill.startDelaySeconds : 0.0;
    final repeats = skill.repeatCount.clamp(1, 128);
    if (_pending.length + repeats > maxPendingActivations) return false;
    final spacing = repeats > 1
        ? _positive(skill.repeatIntervalSeconds) : 0.0;
    // Validate the entire batch before reserving queue slots. Extremely large
    // finite values can still overflow to infinity when combined.
    final lastActivation = at + delay + (repeats - 1) * spacing;
    if (!lastActivation.isFinite) return false;
    for (var i = 0; i < repeats; i++) {
      _pending.add(at + delay + i * spacing);
    }
    final cooldown = skill.cooldownSeconds.isFinite &&
            skill.cooldownSeconds > 0
        ? skill.cooldownSeconds : 0.0;
    final nextReady = at + cooldown;
    // Saturate an overflowing deadline rather than resetting cooldown to
    // the current time, which would allow immediate repeated activations.
    _readyAt = nextReady.isFinite ? nextReady : double.maxFinite;
    return true;
  }

  void _checkTime(double time) {
    if (!time.isFinite || time < 0 || time < _lastTime) {
      throw ArgumentError.value(time, 'time', 'Match time must be finite and monotonic');
    }
    _lastTime = time;
  }
}

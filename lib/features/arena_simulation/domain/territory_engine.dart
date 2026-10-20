class TerritoryEngine {
  static const int totalSectors = 360;

  /// All sectors start unowned ('') -- matches start fully neutral;
  /// territory is only gained by touching the rim or cutting an
  /// opponent's line.
  final List<String> sectorOwners = List.filled(totalSectors, '');

  String? winnerId;

  static const int _slowMotionThreshold = 15;

  /// Each contestant's highest sector count ever seen, used by
  /// [isSlowMotion] to detect a genuine drop from an established
  /// territory rather than firing on a small starting seed.
  final Map<String, int> _peakSectors = {};

  int countSectors(String ballId) =>
      sectorOwners.where((owner) => owner == ballId).length;

  /// Permanently transfers ownership of a single sector to [claimantId], if
  /// it isn't already theirs. Returns whether ownership actually changed.
  bool claimSector(String claimantId, int sectorIndex) {
    if (sectorOwners[sectorIndex] == claimantId) return false;
    sectorOwners[sectorIndex] = claimantId;
    return true;
  }

  /// Records each contestant's highest sector count seen so far. Call this
  /// once per tick before checking [isSlowMotion].
  void updatePeaks(List<String> contestantIds) {
    for (final id in contestantIds) {
      final current = countSectors(id);
      final peak = _peakSectors[id] ?? 0;
      if (current > peak) _peakSectors[id] = current;
    }
  }

  /// True once a contestant that previously exceeded the slow-motion
  /// threshold has dropped back to or below it -- a real drop from an
  /// established position, not just a small starting/seed amount.
  bool isSlowMotion() {
    for (final entry in _peakSectors.entries) {
      if (entry.value <= _slowMotionThreshold) continue;
      final current = countSectors(entry.key);
      if (current > 0 && current <= _slowMotionThreshold) return true;
    }
    return false;
  }

  /// Evaluates win conditions given every ball still in the match
  /// ([contestantIds]). A ball reaching full (360-sector) coverage always
  /// wins. Winning by elimination (only one contestant holds any
  /// territory) is only considered once [allContestantsStarted] is true --
  /// otherwise, in a match that starts fully neutral, the very first ball
  /// to claim its starting seed would trivially "win" before anyone else
  /// had a chance to claim anything.
  void evaluateWinCondition(List<String> contestantIds, {required bool allContestantsStarted}) {
    final ownerCounts = <String, int>{
      for (final id in contestantIds) id: countSectors(id),
    };

    for (final entry in ownerCounts.entries) {
      if (entry.value >= totalSectors) {
        winnerId = entry.key;
        return;
      }
    }

    if (!allContestantsStarted) return;

    final activeOwners = ownerCounts.entries.where((e) => e.value > 0).toList();
    if (activeOwners.length == 1) {
      winnerId = activeOwners.first.key;
    }
  }
}

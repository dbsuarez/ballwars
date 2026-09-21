class TerritoryEngine {
  static const int totalSectors = 360;

  /// All sectors start unowned ('') -- matches start fully neutral;
  /// territory is only gained by touching the rim or cutting an
  /// opponent's line.
  final List<String> sectorOwners = List.filled(totalSectors, '');

  String? winnerId;

  int countSectors(String ballId) =>
      sectorOwners.where((owner) => owner == ballId).length;

  /// Permanently transfers ownership of a single sector to [claimantId], if
  /// it isn't already theirs. Returns whether ownership actually changed.
  bool claimSector(String claimantId, int sectorIndex) {
    if (sectorOwners[sectorIndex] == claimantId) return false;
    sectorOwners[sectorIndex] = claimantId;
    return true;
  }

  bool isSlowMotion() {
    final ownerCounts = <String, int>{};
    for (final owner in sectorOwners) {
      if (owner.isEmpty) continue;
      ownerCounts[owner] = (ownerCounts[owner] ?? 0) + 1;
    }
    return ownerCounts.values.any((count) => count > 0 && count <= 15);
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

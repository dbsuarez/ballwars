class TerritoryEngine {
  static const int totalSectors = 360;

  final List<String> sectorOwners = List.filled(totalSectors, '');

  String? winnerId;

  void initializeSplit(List<String> ballIds) {
    final perBall = totalSectors ~/ ballIds.length;
    for (var i = 0; i < ballIds.length; i++) {
      final start = i * perBall;
      final end = (i == ballIds.length - 1) ? totalSectors : start + perBall;
      for (var s = start; s < end; s++) {
        sectorOwners[s] = ballIds[i];
      }
    }
    winnerId = null;
  }

  int countSectors(String ballId) =>
      sectorOwners.where((owner) => owner == ballId).length;

  /// Permanently transfers ownership of a single sector to [claimantId], if
  /// it isn't already theirs. Returns whether ownership actually changed.
  bool claimSector(String claimantId, int sectorIndex) {
    if (sectorOwners[sectorIndex] == claimantId) return false;
    sectorOwners[sectorIndex] = claimantId;
    _checkWinCondition();
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

  void _checkWinCondition() {
    final ownerCounts = <String, int>{};
    for (final owner in sectorOwners) {
      if (owner.isEmpty) continue;
      ownerCounts[owner] = (ownerCounts[owner] ?? 0) + 1;
    }
    for (final entry in ownerCounts.entries) {
      if (entry.value >= totalSectors) {
        winnerId = entry.key;
        return;
      }
    }
    final activeOwners = ownerCounts.entries.where((e) => e.value > 0).toList();
    if (activeOwners.length == 1) {
      winnerId = activeOwners.first.key;
    }
  }
}

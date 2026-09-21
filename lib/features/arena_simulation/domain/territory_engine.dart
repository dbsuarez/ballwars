import '../../../core/utils/seeded_random.dart';

class StealResult {
  final int stolenCount;
  const StealResult(this.stolenCount);
}

class TerritoryEngine {
  static const int totalSectors = 360;

  final int ballCount;
  final SeededRandom rng;
  final List<String> sectorOwners = List.filled(totalSectors, '');

  String? winnerId;

  TerritoryEngine(this.ballCount, this.rng);

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

  StealResult resolveSteal({required String winnerId, required String loserId}) {
    final loserSectorIndices = <int>[
      for (var i = 0; i < totalSectors; i++)
        if (sectorOwners[i] == loserId) i,
    ];

    final rolled = 20 + rng.nextInt(26); // 20..45
    final clamped = rolled.clamp(10, 75);
    final stealAmount = clamped > loserSectorIndices.length
        ? loserSectorIndices.length
        : clamped;

    for (var i = 0; i < stealAmount; i++) {
      sectorOwners[loserSectorIndices[i]] = winnerId;
    }

    _checkWinCondition();

    return StealResult(stealAmount);
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

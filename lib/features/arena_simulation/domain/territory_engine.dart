import 'package:flutter/material.dart';

class TerritoryEngine {
  static const int totalSectors = 360;

  final List<String> sectorOwners = List.filled(totalSectors, '');

  /// The position each sector's line was claimed from, frozen at the moment
  /// of claiming -- so a sector's line stays put even after the claiming
  /// ball moves away, instead of continuously tracking its live position.
  final List<Offset> sectorClaimOrigin = List.filled(totalSectors, Offset.zero);

  String? winnerId;

  void initializeSplit(List<String> ballIds, List<Offset> ballPositions) {
    final perBall = totalSectors ~/ ballIds.length;
    for (var i = 0; i < ballIds.length; i++) {
      final start = i * perBall;
      final end = (i == ballIds.length - 1) ? totalSectors : start + perBall;
      for (var s = start; s < end; s++) {
        sectorOwners[s] = ballIds[i];
        sectorClaimOrigin[s] = ballPositions[i];
      }
    }
    winnerId = null;
  }

  int countSectors(String ballId) =>
      sectorOwners.where((owner) => owner == ballId).length;

  /// Permanently transfers ownership of a single sector to [claimantId] and
  /// freezes its line's origin at [claimantPosition], if it isn't already
  /// theirs. Returns whether ownership actually changed.
  bool claimSector(String claimantId, int sectorIndex, Offset claimantPosition) {
    if (sectorOwners[sectorIndex] == claimantId) return false;
    sectorOwners[sectorIndex] = claimantId;
    sectorClaimOrigin[sectorIndex] = claimantPosition;
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

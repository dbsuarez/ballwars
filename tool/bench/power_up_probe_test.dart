// Fairness and match-length probe for the power-up modes.
//   flutter test tool/bench/power_up_probe_test.dart
// Prints, per mode and ball count, wins by start position with chi-square, median / 90th-percentile
// match length, unfinished matches (10-minute cap) and how many matches saw a power-up used, plus the
// look-ahead cost of one match construction.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _seeds = 300;
const _cap = 60 * 60 * 10;

void main() {
  test('power-up probe', () {
    final all = [
      for (var i = 0; i < 4; i++)
        CustomBall(id: 'b$i', name: 'B$i', primaryColor: Colors.primaries[i * 3], glowColor: Colors.white),
    ];
    for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
      for (final n in [2, 3, 4]) {
        final wins = List.filled(n, 0);
        final lengths = <double>[];
        var unfinished = 0;
        var used = 0;
        for (var seed = 1; seed <= _seeds; seed++) {
          final c = MatchSimulationController(all.take(n).toList(),
              arenaRadius: 300, seed: seed, mode: mode, slowMotionLines: 0);
          while (c.state.status != MatchStatus.finished && c.stepCount < _cap) {
            c.tick(1 / 60);
          }
          final p = c.powerUps!;
          if (p.shots + p.slashes + p.blasts + p.pickups > 0) used++;
          if (c.state.status != MatchStatus.finished) {
            unfinished++;
            continue;
          }
          wins[int.parse(c.state.winnerId!.substring(1))]++;
          lengths.add(c.stepCount / 60);
        }
        lengths.sort();
        final total = wins.fold(0, (a, b) => a + b);
        final expected = total / n;
        final chi = wins.fold(0.0, (a, w) => a + (w - expected) * (w - expected) / expected);
        final median = lengths.isEmpty ? double.nan : lengths[lengths.length ~/ 2];
        final p90 = lengths.isEmpty ? double.nan : lengths[(lengths.length * 0.9).floor()];
        // ignore: avoid_print
        print('${mode.label.padRight(8)} n=$n wins=$wins chi2=${chi.toStringAsFixed(2)} '
            'median=${median.toStringAsFixed(1)}s p90=${p90.toStringAsFixed(1)}s unfinished=$unfinished '
            'powerUpsUsed=${(100 * used / _seeds).toStringAsFixed(0)}%');
      }
      final sw = Stopwatch()..start();
      for (var seed = 1; seed <= 10; seed++) {
        MatchSimulationController(all.take(2).toList(), arenaRadius: 300, seed: seed, mode: mode);
      }
      // ignore: avoid_print
      print('${mode.label} look-ahead: ${(sw.elapsedMilliseconds / 10).toStringAsFixed(0)} ms per match');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

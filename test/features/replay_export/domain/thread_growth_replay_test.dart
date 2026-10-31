import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';

void main() {
  const contestants = [
    CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.red),
    CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.blue),
  ];

  test('Thread Growth replay preserves mode and maximum threads', () {
    final link = ReplayLink(
      seed: 42,
      speedMultiplier: 1,
      contestants: contestants,
      mode: MatchMode.threadGrowth,
      threadGrowthMaxThreads: 20,
    );
    final uri = link.toUri(presetIds: {'a', 'b'});
    expect(uri.queryParameters['growthmax'], '20');
    expect(uri.queryParameters['balls'], contains('m.threadgrowth'));
    final decoded = ReplayLink.fromUri(uri, presets: contestants);
    expect(decoded, isNotNull);
    expect(decoded!.mode, MatchMode.threadGrowth);
    expect(decoded.threadGrowthMaxThreads, 20);
  });

  test('Thread Growth replay rejects invalid maximum threads', () {
    final uri = ReplayLink(
      seed: 42,
      speedMultiplier: 1,
      contestants: contestants,
      mode: MatchMode.threadGrowth,
      threadGrowthMaxThreads: 20,
    ).toUri(presetIds: {'a', 'b'});
    expect(ReplayLink.fromUri(uri.replace(queryParameters: {
      ...uri.queryParameters,
      'growthmax': '181',
    }), presets: contestants), isNull);
  });
}

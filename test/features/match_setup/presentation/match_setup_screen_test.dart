import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';

void main() {
  testWidgets('START BATTLE is disabled until at least 2 balls are selected', (tester) async {
    final repo = LocalBallRepository();
    MatchConfig? startedConfig;

    await tester.pumpWidget(MaterialApp(
      home: MatchSetupScreen(
        repository: repo,
        onStartBattle: (config) => startedConfig = config,
      ),
    ));

    await tester.tap(find.text('START BATTLE'));
    await tester.pump();
    expect(startedConfig, isNull);

    await tester.tap(find.text('United States'));
    await tester.tap(find.text('Russia'));
    await tester.pump();

    await tester.tap(find.text('START BATTLE'));
    await tester.pump();

    expect(startedConfig, isNotNull);
    expect(startedConfig!.contestants.length, 2);
  });
}

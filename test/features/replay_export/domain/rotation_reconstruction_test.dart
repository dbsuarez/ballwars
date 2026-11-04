import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';
import 'package:ballwars/features/replay_export/domain/replay_document.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/domain/arena_rotation.dart';

void main() {
  test(
    'custom-only saved/server snapshot spawns the custom skill without built-ins',
    () async {
      OfflineStore.instance = MemoryOfflineStore();
      final balls = LocalBallRepository.presets.take(2).toList();
      final skill = SkillLibrary.defaults
          .builtIn(PowerUpKind.boomerang, PowerUpConfig.defaults)
          .copyWith(id: 'custom.boom', name: 'Boom', custom: true);
      final library = SkillLibrary(custom: [skill]);
      final original = ReplayLink(
        seed: 42,
        speedMultiplier: 1,
        contestants: balls,
        simulationRevision: 7,
        mode: MatchMode.arsenal,
        powerUps: const {},
        customSkills: const {'custom.boom'},
        skillLibrary: library,
      );
      final uri = original.toUri(presetIds: balls.map((b) => b.id).toSet());
      await SavedReplayStore.add(uri);
      final stored = Uri.parse((await SavedReplayStore.load()).single.uri);
      final document = ReplayDocument.decode(
        ReplayDocument(stored.queryParameters).encode(),
      );
      final decoded = ReplayLink.fromUri(
        stored.replace(queryParameters: document.query),
        presets: balls,
      )!;
      final replay = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: decoded.seed,
        mode: decoded.mode,
        powerUpKinds: decoded.powerUps,
        customSkillIds: decoded.customSkills,
        skillLibrary: decoded.skillLibrary,
        simulationRevision: decoded.simulationRevision,
        lookAhead: false,
      );
      final seen = <String?>{};
      for (var i = 0; i < 1800; i++) {
        replay.tick(1 / 60);
        seen.addAll(replay.powerUps!.field.map((p) => p.skillId));
      }
      expect(seen, {'custom.boom'});
    },
  );

  test(
    'saved and server-document replays preserve post-transition state and final outcome',
    () async {
      OfflineStore.instance = MemoryOfflineStore();
      final balls = List.generate(
        6,
        (i) => CustomBall(
          id: 'test$i',
          name: 'Ball $i',
          primaryColor: LocalBallRepository
              .presets[i % LocalBallRepository.presets.length]
              .primaryColor,
          glowColor: LocalBallRepository
              .presets[i % LocalBallRepository.presets.length]
              .glowColor,
        ),
      );
      const rotation = ArenaRotation(
        rotateThemes: true,
        rotateShapes: true,
        intervalSeconds: 30,
      );
      final original = ReplayLink(
        seed: 314,
        speedMultiplier: 1,
        contestants: balls,
        simulationRevision: 7,
        mode: MatchMode.arsenal,
        endlessBattle: true,
        mayhem: true,
        mayhemSeconds: 90,
        powerUps: const {},
        customSkills: const {},
        arenaRotation: rotation,
      );
      final uri = original.toUri(presetIds: balls.map((b) => b.id).toSet());
      await SavedReplayStore.add(uri);
      final stored = Uri.parse((await SavedReplayStore.load()).first.uri);
      final document = ReplayDocument.decode(
        ReplayDocument(stored.queryParameters).encode(),
      );
      final decoded = ReplayLink.fromUri(
        stored.replace(queryParameters: document.query),
        presets: balls,
      )!;
      expect(decoded.powerUps, isEmpty);
      expect(decoded.customSkills, isEmpty);
      MatchSimulationController reconstruct(ReplayLink link) =>
          MatchSimulationController(
            balls,
            arenaRadius: 260,
            seed: link.seed,
            simulationRevision: link.simulationRevision,
            mode: link.mode,
            endlessBattle: link.endlessBattle,
            mayhem: link.mayhem,
            mayhemSeconds: link.mayhemSeconds,
            powerUpKinds: link.powerUps,
            customSkillIds: link.customSkills,
            arenaRotation: link.arenaRotation,
            lookAhead: false,
          );
      final live = reconstruct(original), replay = reconstruct(decoded);
      for (var step = 0; step < 5401; step++) {
        live.tick(1 / 60);
        replay.tick(1 / 60);
        if (step == 1850 || step == 3650 || step == 5400) {
          expect(replay.state.arenaShape, live.state.arenaShape);
          expect(replay.arenaDecoration, live.arenaDecoration);
          expect(replay.eliminations, live.eliminations);
          expect(replay.deaths, live.deaths);
          expect(
            replay.state.balls.map((b) => [b.position, b.velocity, b.life]),
            live.state.balls.map((b) => [b.position, b.velocity, b.life]),
          );
        }
      }
      expect(replay.state.winnerId, live.state.winnerId);
      expect(replay.state.winnerId, isNotNull);
    },
  );
}

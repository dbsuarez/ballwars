import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arenas/domain/arena_placement.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';
import 'package:ballwars/features/arenas/presentation/arena_background_import.dart';

final balls = List.generate(
  8,
  (i) => CustomBall(
    id: 'rule-$i',
    name: 'Ball $i',
    primaryColor: const Color(0xff4488ff),
    glowColor: const Color(0xffffffff),
  ),
);
MatchSimulationController growth({bool race = false, int target = 50}) =>
    MatchSimulationController(
      balls.take(2).toList(),
      arenaRadius: 200,
      seed: 10,
      simulationRevision: 10,
      lookAhead: false,
      mode: MatchMode.threadGrowth,
      threadCutRace: race,
      neoThreadsTarget: target,
    );
void main() {
  test('Cut Race survival skips unused prediction without changing outcomes', () {
    MatchSimulationController create(bool lookAhead)=>MatchSimulationController(balls.take(2).toList(),arenaRadius:200,
      seed:34,simulationRevision:10,mode:MatchMode.threadGrowth,threadCutRace:true,lookAhead:lookAhead);
    final fast=create(true),reference=create(false);
    expect(fast.predictedFinishStep,isNull);
    for(var step=0;step<1200;step++) {
      fast.tick(1/60);reference.tick(1/60);
      expect(fast.state.status,reference.state.status);
      expect(fast.state.winnerId,reference.state.winnerId);
      for(var i=0;i<2;i++) {
        expect(fast.state.balls[i].position,reference.state.balls[i].position);
        expect(fast.state.balls[i].threadsCut,reference.state.balls[i].threadsCut);
      }
    }
  });

  test('Mayhem ghost floats before delayed safe respawn and never ends the match', () {
    final match=MatchSimulationController(balls.take(2).toList(),arenaRadius:200,seed:30,
      lookAhead:false,simulationRevision:10,mode:MatchMode.arsenal,mayhem:true,endlessBattle:true,
      powerUpKinds:const {});
    final b=match.state.balls.first; b.life=0; match.tick(1/60);
    expect(b.isEliminated,true); expect(match.state.deathGhosts,hasLength(1));
    expect(match.deaths[b.config.id],1); expect(match.state.status,isNot(MatchStatus.finished));
    for(var i=0;i<20;i++) { match.tick(1/60); }
    expect(b.isEliminated,true); expect(match.state.deathGhosts.single.age,greaterThan(0));
    for(var i=0;i<26;i++) { match.tick(1/60); }
    expect(b.isEliminated,false); expect(b.life,greaterThan(0)); expect(b.ghostLeft,greaterThan(0));
    expect(match.state.deathGhosts,isEmpty); expect(match.deaths[b.config.id],1);
  });
  test('older replay revisions retain immediate endless respawn', () {
    final match=MatchSimulationController(balls.take(2).toList(),arenaRadius:200,seed:30,
      lookAhead:false,simulationRevision:9,mode:MatchMode.arsenal,endlessBattle:true,powerUpKinds:const {});
    final b=match.state.balls.first; b.life=0; match.tick(1/60);
    expect(b.isEliminated,false); expect(match.state.deathGhosts,isEmpty);
  });

  test('modifier off preserves elimination and fixed radius', () {
    final match = growth();
    final b = match.state.balls.first;
    final radius = b.radius;
    for (final line in b.fanLines) {
      line.isActive = false;
    }
    match.tick(1 / 60);
    expect(b.isEliminated, true);
    expect(b.radius, radius);
  });
  test(
    'zero-thread survival can be disabled without changing ordinary growth',
    () {
      final match = MatchSimulationController(
        balls.take(2).toList(),
        arenaRadius: 200,
        seed: 10,
        simulationRevision: 10,
        lookAhead: false,
        mode: MatchMode.threadGrowth,
        threadCutRace: true,
        cutRaceSurvival: false,
      );
      final b = match.state.balls.first;
      for (final line in b.fanLines) {
        line.isActive = false;
      }
      match.tick(1 / 60);
      expect(b.isEliminated, true);
      expect(match.state.winnerId, match.state.balls.last.config.id);
    },
  );
  test('Cut Race keeps zero-thread balls alive and shrinks their body', () {
    final match = growth(race: true);
    final b = match.state.balls.first;

    for (final line in b.fanLines) {
      line.isActive = false;
    }
    match.tick(1 / 60);
    expect(b.isEliminated, false);
    expect(b.radius, 200 * MatchSimulationController.ballRadiusRatio * .5);
    expect(match.state.status, isNot(MatchStatus.finished));
  });
  test('size continues growing beyond the second owned thread', () {
    final match=growth(race:true,target:1000); final b=match.state.balls.first;
    final small=b.radius; match.claimFreeSlots(b,10); match.tick(1/60);
    expect(b.fanLines.length,greaterThan(2)); expect(b.radius,greaterThan(small));
    expect(b.radius,closeTo(200*.107*(.5+b.fanLines.length/180),.00001));
  });
  test('actual cuts credit cutter and finish at configured target', () {
    final match = growth(race: true, target: 1);
    final cutter = match.state.balls.first, target = match.state.balls.last;
    final line = target.fanLines.single;
    cutter.position = (line.startPoint + target.position) / 2;
    cutter.velocity = Offset.zero;
    target.velocity = Offset.zero;
    match.tick(1 / 60);
    expect(cutter.threadsCut, greaterThanOrEqualTo(1));
    expect(match.state.winnerId, cutter.config.id);
    expect(match.state.status, MatchStatus.finished);
  });
  test(
    'Cut Race target and eight-ball Mayhem round-trip with revision guard',
    () {
      for (final count in [6, 7, 8]) {
        final link = ReplayLink(
          contestants: balls.take(count).toList(),
          seed: 1,
          speedMultiplier: 1,
          simulationRevision: 10,
          mode: MatchMode.arsenal,
          mayhem: true,
          endlessBattle: true,
        );
        final parsed = ReplayLink.fromUri(
          link.toUri(presetIds: const {}),
          presets: const [],
        );
        expect(parsed!.contestants, hasLength(count));
      }
      final link = ReplayLink(
        contestants: balls.take(2).toList(),
        seed: 1,
        speedMultiplier: 1,
        simulationRevision: 10,
        mode: MatchMode.threadGrowth,
        threadCutRace: true,
        neoThreadsTarget: 100,
      );
      final uri = link.toUri(presetIds: const {});
      final parsed = ReplayLink.fromUri(uri, presets: const [])!;
      expect(parsed.threadCutRace, true);
      expect(parsed.neoThreadsTarget, 100);
      expect(
        ReplayLink.fromUri(
          uri.replace(
            queryParameters: {...uri.queryParameters, 'neotarget': '0'},
          ),
          presets: const [],
        ),
        isNull,
      );
      expect(
        ReplayLink.fromUri(
          Uri.parse(uri.toString().replaceAll('v.10', 'v.9')),
          presets: const [],
        ),
        isNull,
      );
    },
  );
  test('eight contestants spawn safely, deterministic without overlaps', () {
    MatchSimulationController create() => MatchSimulationController(
      balls,
      arenaRadius: 200,
      seed: 11,
      simulationRevision: 10,
      lookAhead: false,
      mode: MatchMode.arsenal,
      mayhem: true,
      endlessBattle: true,
      centerObstacle: CenterObstacle.square,
      centerObstacleScale: .3,
    );
    final a = create(), b = create();
    for (var i = 0; i < 8; i++) {
      final ball = a.state.balls[i];
      expect(ball.position, b.state.balls[i].position);
      expect(
        ArenaPlacement.fits(
          ball.position,
          radius: 200,
          ballRadius: ball.radius,
          shape: ArenaShape.circle,
          obstacle: CenterObstacle.square,
          obstacleScale: .3,
        ),
        true,
      );
      for (var j = 0; j < i; j++) {
        expect(
          (ball.position - a.state.balls[j].position).distance,
          greaterThanOrEqualTo(ball.radius + a.state.balls[j].radius),
        );
      }
    }
  });
  test(
    'test placement preserves velocity, equipment and pinned idle position',
    () {
      final match = MatchSimulationController(
        balls.take(2).toList(),
        arenaRadius: 200,
        lookAhead: false,
        mode: MatchMode.arsenal,
        centerObstacle: CenterObstacle.square,
      );
      final b = match.state.balls.first;
      final velocity = b.velocity;
      match.setTestBallPinned(b, true);
      expect(match.placeTestBall(b, Offset.zero), true);
      final position = b.position;
      expect(
        ArenaPlacement.fits(
          position,
          radius: 200,
          ballRadius: b.radius,
          shape: ArenaShape.circle,
          obstacle: CenterObstacle.square,
          obstacleScale: .22,
        ),
        true,
      );
      match.tick(1 / 60);
      expect(b.position, position);
      match.setTestBallPinned(b, false);
      expect(b.velocity, velocity);
    },
  );
  test('clearance considers minimum shrink and square obstacle corners', () {
    expect(
      ArenaPlacement.problem(
        shape: ArenaShape.circle,
        obstacle: CenterObstacle.square,
        obstacleScale: .34,
        minimumScale: .6,
        ballRadiusRatio: .2,
      ),
      isNotNull,
    );
    expect(
      ArenaPlacement.problem(
        shape: ArenaShape.square,
        obstacle: CenterObstacle.circle,
        obstacleScale: .22,
        minimumScale: .6,
        ballRadiusRatio: .13375,
      ),
      isNull,
    );
  });
  test('crop stays square and within source at every control extreme', () {
    for (final zoom in [1.0, 4.0]) {
      for (final x in [0.0, 1.0]) {
        final rect = arenaBackgroundCrop(const Size(1600, 900), zoom, x, 1);
        expect(rect.width, rect.height);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(1600));
        expect(rect.bottom, lessThanOrEqualTo(900));
      }
    }
  });
}

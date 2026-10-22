import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';

const _presets = LocalBallRepository.presets;
final _presetIds = {for (final b in _presets) b.id};

const _custom = CustomBall(
  id: 'my-ball-123',
  name: 'Ñandú & Co.',
  primaryColor: Color(0xFF12AB34),
  glowColor: Color(0x8056CDEF),
  baseSpeed: 400,
  mass: 1.5,
);

void main() {
  test('round-trips preset and custom balls, seed and speed, in order', () {
    final link = ReplayLink(
      seed: 1792650442501,
      speedMultiplier: 1.5,
      contestants: [_custom, _presets[1], _presets[0]],
    );

    final uri = link.toUri(presetIds: _presetIds, appUrl: 'https://dbsuarez.github.io/ballwars/');
    expect(uri.toString(), startsWith('https://dbsuarez.github.io/ballwars/?seed=1792650442501&speed=1.5&balls='));
    expect(uri.toString(), isNot(contains('#')));

    final parsed = ReplayLink.fromUri(uri, presets: _presets)!;
    expect(parsed.seed, 1792650442501);
    expect(parsed.speedMultiplier, 1.5);
    expect(parsed.contestants.map((b) => b.name), ['Ñandú & Co.', 'Russia', 'United States']);
    final custom = parsed.contestants.first;
    expect(custom.primaryColor, _custom.primaryColor);
    expect(custom.glowColor, _custom.glowColor);
    expect(custom.baseSpeed, 400);
    expect(custom.mass, 1.5);
    expect(parsed.contestants[1], same(_presets[1]));
  });

  test('a linked match plays out exactly like the original', () {
    final original = [_custom, _presets[2]];
    final uri = ReplayLink(seed: 7, speedMultiplier: 1, contestants: original)
        .toUri(presetIds: _presetIds, appUrl: kWebAppUrl);
    final parsed = ReplayLink.fromUri(uri, presets: _presets)!;

    MatchSimulationController play(List<CustomBall> balls) {
      final c = MatchSimulationController(balls, arenaRadius: 260, seed: 7);
      while (c.state.status != MatchStatus.finished) {
        c.tick(1 / 60);
      }
      return c;
    }

    final a = play(original);
    final b = play(parsed.contestants);
    expect(b.elapsedSeconds, a.elapsedSeconds);
    expect(b.state.balls.map((x) => x.position), a.state.balls.map((x) => x.position));
    expect(original.indexWhere((x) => x.id == a.state.winnerId),
        parsed.contestants.indexWhere((x) => x.id == b.state.winnerId));
  });

  test('anything that is not a complete replay link is ignored', () {
    ReplayLink? parse(String s) => ReplayLink.fromUri(Uri.parse(s), presets: _presets);

    expect(parse('https://dbsuarez.github.io/ballwars/'), isNull);
    expect(parse('https://x/#/replay?balls=p.preset-usa,p.preset-russia'), isNull); // no seed
    expect(parse('https://x/#/replay?seed=1&balls=p.preset-usa'), isNull); // one ball
    expect(parse('https://x/#/replay?seed=1&balls=p.preset-usa,p.nope'), isNull); // unknown preset
    expect(parse('https://x/#/replay?seed=1&balls=p.preset-usa,c.%%%'), isNull); // garbage
    expect(parse('https://x/?seed=1&balls=p.preset-usa,p.preset-russia'), isNotNull);
    expect(parse('https://x/?seed=1&balls=p.preset-usa'), isNull);
    // Links made before the '#' was dropped still work.
    expect(parse('https://x/#/replay?seed=1&balls=p.preset-usa,p.preset-russia'), isNotNull);
  });

  test('pack balls travel by id and come back with their logo', () {
    const netflix = CustomBall(
      id: 'pack:streaming/netflix',
      name: 'Netflix',
      imageUrl: 'https://dbsuarez.github.io/ballwars/packs/streaming/netflix.svg',
      imageStyle: BallImageStyle.logo,
      primaryColor: Color(0xFFE50914),
      glowColor: Color(0xFFFF6B6B),
    );
    final uri = ReplayLink(seed: 3, speedMultiplier: 1, contestants: [netflix, _presets[0]])
        .toUri(presetIds: _presetIds, appUrl: kWebAppUrl);

    expect(uri.toString(), contains('balls=k.streaming/netflix,p.preset-usa'));
    expect(ReplayLink.usesPacks(uri), isTrue);
    // Without the packs loaded the link can't be resolved...
    expect(ReplayLink.fromUri(uri, presets: _presets), isNull);
    // ...with them it resolves to the same ball, image included.
    final parsed = ReplayLink.fromUri(uri, presets: _presets, packBalls: {netflix.id: netflix})!;
    expect(parsed.contestants.first, same(netflix));
  });

  test('links remember when sparks and particles were turned off', () {
    final off = ReplayLink(seed: 1, speedMultiplier: 1, showEffects: false, contestants: [_presets[0], _presets[1]])
        .toUri(presetIds: _presetIds, appUrl: kWebAppUrl);
    final on = ReplayLink(seed: 1, speedMultiplier: 1, contestants: [_presets[0], _presets[1]])
        .toUri(presetIds: _presetIds, appUrl: kWebAppUrl);

    expect(off.toString(), contains('fx=0'));
    expect(on.toString(), isNot(contains('fx=')));
    expect(ReplayLink.fromUri(off, presets: _presets)!.showEffects, isFalse);
    expect(ReplayLink.fromUri(on, presets: _presets)!.showEffects, isTrue);
  });
}


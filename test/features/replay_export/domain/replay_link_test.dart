import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
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

  group('crafted links are rejected', () {
    ReplayLink? parse(String query) =>
        ReplayLink.fromUri(Uri.parse('https://dbsuarez.github.io/ballwars/?$query'), presets: _presets);
    String custom(Map<String, Object> data) =>
        'c.${base64Url.encode(utf8.encode(jsonEncode({'n': 'X', 'p': 0xFFFF0000, 'g': 0xFFFF8888, 's': 320, 'm': 1, ...data}))).replaceAll('=', '')}';
    final two = 'p.${_presets[0].id},p.${_presets[1].id}';

    test('a valid link still parses', () {
      expect(parse('seed=1&speed=1&balls=$two'), isNotNull);
      expect(parse('seed=1&speed=1&balls=$two,${custom({})}'), isNotNull);
    });

    test('ball count must be 2-4', () {
      final five = List.filled(5, 'p.${_presets[0].id}').join(',');
      expect(parse('seed=1&balls=p.${_presets[0].id}'), isNull);
      expect(parse('seed=1&balls=$five'), isNull);
    });

    test('speed must be finite and in range', () {
      for (final speed in ['-1', '0', 'NaN', 'Infinity', '1e9', '0.1']) {
        expect(parse('seed=1&speed=$speed&balls=$two'), isNull, reason: speed);
      }
    });

    test('custom balls need sane mass, speed and name', () {
      expect(parse('seed=1&balls=$two,${custom({'m': 1000})}'), isNull);
      expect(parse('seed=1&balls=$two,${custom({'s': -5})}'), isNull);
      expect(parse('seed=1&balls=$two,${custom({'n': 'x' * 200})}'), isNull);
      expect(parse('seed=1&balls=$two,${custom({'n': '  '})}'), isNull);
    });

    test('oversized links are rejected before parsing', () {
      expect(parse('seed=1&balls=$two&pad=${'a' * 5000}'), isNull);
    });
  });

  test('mode travels as a ball-list token; Threads links have none', () {
    final ids = {for (final b in _presets) b.id};
    const app = 'https://dbsuarez.github.io/ballwars/';
    final uri = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      mode: MatchMode.allOut,
    ).toUri(presetIds: ids, appUrl: app);
    expect(uri.queryParameters['balls'], startsWith('m.allout,'));
    final parsed = ReplayLink.fromUri(uri, presets: _presets)!;
    expect(parsed.mode, MatchMode.allOut);
    expect(parsed.contestants, hasLength(2));

    final threads = ReplayLink(seed: 5, speedMultiplier: 1, contestants: [_presets[0], _presets[1]])
        .toUri(presetIds: ids, appUrl: app);
    expect(threads.queryParameters['balls'], isNot(contains('m.')));
  });

  test('an unknown mode token is rejected', () {
    ReplayLink? parse(String balls) =>
        ReplayLink.fromUri(Uri.parse('https://x/?seed=1&balls=$balls'), presets: _presets);
    final two = 'p.${_presets[0].id},p.${_presets[1].id}';
    expect(parse('m.laser,$two'), isNull);
    expect(parse(two)!.mode, MatchMode.threads);
    expect(parse('m.arsenal,$two')!.mode, MatchMode.arsenal);
    // Old '#/replay?' links carry the mode the same way.
    final legacy = ReplayLink.fromUri(Uri.parse('https://x/#/replay?seed=1&balls=m.allout,$two'), presets: _presets);
    expect(legacy!.mode, MatchMode.allOut);
    expect(legacy.contestants.length, 2);
  });

  test('ball size travels in the link; old links are medium; unknown sizes are rejected', () {
    final link = ReplayLink(seed: 5, speedMultiplier: 1, contestants: [_presets[0], _presets[1]], ballSize: BallSize.large);
    final uri = link.toUri(presetIds: {for (final b in _presets) b.id}, appUrl: 'https://dbsuarez.github.io/ballwars/');
    expect(uri.queryParameters['size'], 'l');
    expect(ReplayLink.fromUri(uri, presets: _presets)!.ballSize, BallSize.large);

    final medium = ReplayLink(seed: 5, speedMultiplier: 1, contestants: [_presets[0], _presets[1]])
        .toUri(presetIds: {for (final b in _presets) b.id}, appUrl: 'https://dbsuarez.github.io/ballwars/');
    expect(medium.queryParameters.containsKey('size'), isFalse);
    expect(ReplayLink.fromUri(medium, presets: _presets)!.ballSize, BallSize.medium);

    final bad = uri.replace(queryParameters: {...uri.queryParameters, 'size': 'huge'});
    expect(ReplayLink.fromUri(bad, presets: _presets), isNull);
  });

  test('a Yes or No question travels as q=, trimmed and on one line', () {
    final link = ReplayLink(seed: 5, speedMultiplier: 1, contestants: [_presets[0], _presets[1]], question: 'Will it rain?');
    final uri = link.toUri(presetIds: {for (final b in _presets) b.id}, appUrl: 'https://dbsuarez.github.io/ballwars/');
    expect(uri.queryParameters['q'], 'Will it rain?');
    expect(ReplayLink.fromUri(uri, presets: _presets)!.question, 'Will it rain?');

    final none = ReplayLink(seed: 5, speedMultiplier: 1, contestants: [_presets[0], _presets[1]])
        .toUri(presetIds: {for (final b in _presets) b.id}, appUrl: 'https://dbsuarez.github.io/ballwars/');
    expect(none.queryParameters.containsKey('q'), isFalse);
    expect(ReplayLink.fromUri(none, presets: _presets)!.question, isNull);

    final messy = uri.replace(queryParameters: {...uri.queryParameters, 'q': '  Line one\nline two  ${'x' * 200}'});
    final q = ReplayLink.fromUri(messy, presets: _presets)!.question!;
    expect(q.contains('\n'), isFalse);
    expect(q.length, lessThanOrEqualTo(100));
  });

  test('chosen power-ups travel as a w. token; all chosen adds none; bad tokens are rejected', () {
    const app = 'https://dbsuarez.github.io/ballwars/';
    final ids = {for (final b in _presets) b.id};
    final some = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      mode: MatchMode.arsenal,
      powerUps: {PowerUpKind.knife, PowerUpKind.mine},
    ).toUri(presetIds: ids, appUrl: app);
    final tokens = some.queryParameters['balls']!.split(',');
    expect(tokens[0], 'm.arsenal');
    expect(tokens[1], startsWith('w.'));
    expect(ReplayLink.fromUri(some, presets: _presets)!.powerUps, {PowerUpKind.knife, PowerUpKind.mine});

    final all = ReplayLink(seed: 5, speedMultiplier: 1, contestants: [_presets[0], _presets[1]], mode: MatchMode.arsenal)
        .toUri(presetIds: ids, appUrl: app);
    expect(all.queryParameters['balls']!.contains('w.'), isFalse);
    expect(ReplayLink.fromUri(all, presets: _presets)!.powerUps, isNull);

    ReplayLink? withBalls(String balls) =>
        ReplayLink.fromUri(Uri.parse('$app?seed=1&balls=$balls'), presets: _presets);
    final a = 'p.${_presets[0].id}';
    final b = 'p.${_presets[1].id}';
    expect(withBalls('w.3,$a,$b'), isNull, reason: 'w. needs a power-up mode');
    expect(withBalls('m.arsenal,w.0,$a,$b'), isNull, reason: 'empty selection');
    expect(withBalls('m.arsenal,w.zzzz,$a,$b'), isNull, reason: 'bits beyond the 11 kinds');
  });

  test('power-up numbers travel in the link; threads links and bad values are rejected', () {
    final tuning = PowerUpConfig.defaults.withValue('dmg.pistol', 33).withValue('aim', 0.5);
    final link = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      mode: MatchMode.arsenal,
      tuning: tuning,
    );
    final uri = link.toUri(presetIds: {for (final b in _presets) b.id});
    expect(uri.queryParameters['t'], tuning.encode());
    final back = ReplayLink.fromUri(uri, presets: _presets)!;
    expect(back.tuning, tuning);

    // Defaults add nothing, so older apps keep reading these links.
    final plain = ReplayLink(seed: 5, speedMultiplier: 1, contestants: [_presets[0], _presets[1]], mode: MatchMode.arsenal)
        .toUri(presetIds: {for (final b in _presets) b.id});
    expect(plain.queryParameters.containsKey('t'), isFalse);
    expect(ReplayLink.fromUri(plain, presets: _presets)!.tuning, PowerUpConfig.defaults);

    final two = 'p.${_presets[0].id},p.${_presets[1].id}';
    ReplayLink? parse(String query) => ReplayLink.fromUri(Uri.parse('https://x/?$query'), presets: _presets);
    expect(parse('seed=1&t=${tuning.encode()}&balls=$two'), isNull, reason: 'threads match with numbers');
    expect(parse('seed=1&t=garbage!&balls=m.arsenal,$two'), isNull);
    expect(parse('seed=1&t=${PowerUpConfig(const {'dmg.pistol': 5000}).encode()}&balls=m.arsenal,$two'), isNull);
  });
}

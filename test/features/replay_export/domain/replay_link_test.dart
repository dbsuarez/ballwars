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
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

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

/// Pickups that spawned in the first minute of a seeded Arsenal match, in order.
List<String> _spawnedKinds(ReplayLink link) {
  final c = MatchSimulationController(
    link.contestants,
    arenaRadius: 260,
    seed: link.seed,
    mode: link.mode,
    lookAhead: false,
    powerUpKinds: link.powerUps,
    tuning: link.tuning,
    simulationRevision: link.simulationRevision,
  );
  final seen = <FieldPowerUp>{};
  final kinds = <String>[];
  for (var i = 0; i < 3600; i++) {
    c.tick(1 / 60);
    for (final f in c.powerUps!.field) {
      if (seen.add(f)) kinds.add(f.kind.name);
    }
  }
  return kinds;
}

/// A `t=` as the app wrote it before Shadow Clone: a 48-kind tier list.
String _legacyTuning() {
  final current = PowerUpConfig.defaults.encode()!;
  final json =
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(current))))
          as Map<String, Object?>;
  json['_tiers'] = (json['_tiers'] as String).substring(
    0,
    ReplayLink.legacyKindCount,
  );
  return base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
}

void main() {
  test('new mirrored-origin rules keep older replay versions readable', () {
    for (final revision in [1, 2, 3, 4]) {
      final link = ReplayLink(
        seed: 1,
        speedMultiplier: 1,
        contestants: _presets.take(2).toList(),
        simulationRevision: revision,
      );
      final uri = link.toUri(
        presetIds: _presetIds,
        appUrl: 'https://dbsuarez.github.io/ballwars/',
      );
      expect(
        ReplayLink.fromUri(uri, presets: _presets)!.simulationRevision,
        revision,
      );
    }
  });
  test(
    'simulation revision preserves legacy links and rejects unknown rules',
    () {
      for (final revision in [1, 2, 3]) {
        final encoded = ReplayLink(
          simulationRevision: revision,
          seed: 7,
          speedMultiplier: 1,
          contestants: _presets.take(2).toList(),
        ).toUri(presetIds: _presetIds, appUrl: 'https://example.com/');
        final decoded = ReplayLink.fromUri(encoded, presets: _presets);
        expect(decoded, isNotNull);
        expect(decoded!.simulationRevision, revision);
        expect(
          decoded
              .toUri(presetIds: _presetIds)
              .toString()
              .contains('v.$revision'),
          revision >= 2,
        );
        if (revision == 2) {
          expect(
            ReplayLink.fromUri(
              Uri.parse(encoded.toString().replaceFirst('v.2', 'v.99')),
              presets: _presets,
            ),
            isNull,
          );
        }
      }
    },
  );
  test('random hairstyle choice is preserved in replay links', () {
    final uri = ReplayLink(
      seed: 19,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      randomizedHairstyles: true,
    ).toUri(presetIds: _presetIds, appUrl: 'https://example.com/');

    expect(uri.queryParameters['hair'], '1');
    expect(
      ReplayLink.fromUri(uri, presets: _presets)!.randomizedHairstyles,
      isTrue,
    );
  });

  test('round-trips preset and custom balls, seed and speed, in order', () {
    final link = ReplayLink(
      seed: 1792650442501,
      speedMultiplier: 1.5,
      contestants: [_custom, _presets[1], _presets[0]],
    );

    final uri = link.toUri(
      presetIds: _presetIds,
      appUrl: 'https://dbsuarez.github.io/ballwars/',
    );
    expect(
      uri.toString(),
      startsWith(
        'https://dbsuarez.github.io/ballwars/?seed=1792650442501&speed=1.5&balls=',
      ),
    );
    expect(uri.toString(), isNot(contains('#')));

    final parsed = ReplayLink.fromUri(uri, presets: _presets)!;
    expect(parsed.seed, 1792650442501);
    expect(parsed.speedMultiplier, 1.5);
    expect(parsed.contestants.map((b) => b.name), [
      'Ñandú & Co.',
      'Russia',
      'United States',
    ]);
    final custom = parsed.contestants.first;
    expect(custom.primaryColor, _custom.primaryColor);
    expect(custom.glowColor, _custom.glowColor);
    expect(custom.baseSpeed, 400);
    expect(custom.mass, 1.5);
    expect(parsed.contestants[1], same(_presets[1]));
  });

  test('round-trips disabled automatic speed-up', () {
    final uri = ReplayLink(
      seed: 7,
      speedMultiplier: 1,
      automaticSpeedUp: false,
      contestants: [_presets[0], _presets[1]],
    ).toUri(presetIds: _presetIds, appUrl: kWebAppUrl);

    expect(uri.queryParameters['autospeed'], '0');
    final parsed = ReplayLink.fromUri(uri, presets: _presets)!;
    expect(parsed.automaticSpeedUp, isFalse);
  });

  test('round-trips the player-selected arena', () {
    final uri = ReplayLink(
      seed: 8,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      arenaDecoration: ArenaDecoration.wilderness,
    ).toUri(presetIds: _presetIds, appUrl: kWebAppUrl);

    expect(uri.queryParameters['arena'], 'wilderness');
    expect(
      ReplayLink.fromUri(uri, presets: _presets)!.arenaDecoration,
      ArenaDecoration.wilderness,
    );
  });

  test('a linked match plays out exactly like the original', () {
    final original = [_custom, _presets[2]];
    final uri = ReplayLink(
      seed: 7,
      speedMultiplier: 1,
      contestants: original,
    ).toUri(presetIds: _presetIds, appUrl: kWebAppUrl);
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
    expect(
      b.state.balls.map((x) => x.position),
      a.state.balls.map((x) => x.position),
    );
    expect(
      original.indexWhere((x) => x.id == a.state.winnerId),
      parsed.contestants.indexWhere((x) => x.id == b.state.winnerId),
    );
  });

  test('anything that is not a complete replay link is ignored', () {
    ReplayLink? parse(String s) =>
        ReplayLink.fromUri(Uri.parse(s), presets: _presets);

    expect(parse('https://dbsuarez.github.io/ballwars/'), isNull);
    expect(
      parse('https://x/#/replay?balls=p.preset-usa,p.preset-russia'),
      isNull,
    ); // no seed
    expect(
      parse('https://x/#/replay?seed=1&balls=p.preset-usa'),
      isNull,
    ); // one ball
    expect(
      parse('https://x/#/replay?seed=1&balls=p.preset-usa,p.nope'),
      isNull,
    ); // unknown preset
    expect(
      parse('https://x/#/replay?seed=1&balls=p.preset-usa,c.%%%'),
      isNull,
    ); // garbage
    expect(
      parse('https://x/?seed=1&balls=p.preset-usa,p.preset-russia'),
      isNotNull,
    );
    expect(parse('https://x/?seed=1&balls=p.preset-usa'), isNull);
    // Links made before the '#' was dropped still work.
    expect(
      parse('https://x/#/replay?seed=1&balls=p.preset-usa,p.preset-russia'),
      isNotNull,
    );
  });

  test('pack balls travel by id and come back with their logo', () {
    const netflix = CustomBall(
      id: 'pack:streaming/netflix',
      name: 'Netflix',
      imageUrl:
          'https://dbsuarez.github.io/ballwars/packs/streaming/netflix.svg',
      imageStyle: BallImageStyle.logo,
      primaryColor: Color(0xFFE50914),
      glowColor: Color(0xFFFF6B6B),
    );
    final uri = ReplayLink(
      seed: 3,
      speedMultiplier: 1,
      contestants: [netflix, _presets[0]],
    ).toUri(presetIds: _presetIds, appUrl: kWebAppUrl);

    expect(
      uri.toString(),
      contains('balls=v.4,k.streaming/netflix,p.preset-usa'),
    );
    expect(ReplayLink.usesPacks(uri), isTrue);
    // Without the packs loaded the link can't be resolved...
    expect(ReplayLink.fromUri(uri, presets: _presets), isNull);
    // ...with them it resolves to the same ball, image included.
    final parsed = ReplayLink.fromUri(
      uri,
      presets: _presets,
      packBalls: {netflix.id: netflix},
    )!;
    expect(parsed.contestants.first, same(netflix));
  });

  test('links remember when sparks and particles were turned off', () {
    final off = ReplayLink(
      seed: 1,
      speedMultiplier: 1,
      showEffects: false,
      contestants: [_presets[0], _presets[1]],
    ).toUri(presetIds: _presetIds, appUrl: kWebAppUrl);
    final on = ReplayLink(
      seed: 1,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
    ).toUri(presetIds: _presetIds, appUrl: kWebAppUrl);

    expect(off.toString(), contains('fx=0'));
    expect(on.toString(), isNot(contains('fx=')));
    expect(ReplayLink.fromUri(off, presets: _presets)!.showEffects, isFalse);
    expect(ReplayLink.fromUri(on, presets: _presets)!.showEffects, isTrue);
  });

  group('crafted links are rejected', () {
    ReplayLink? parse(String query) => ReplayLink.fromUri(
      Uri.parse('https://dbsuarez.github.io/ballwars/?$query'),
      presets: _presets,
    );
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

    test('custom balls carry their gender as x; unknown values reject', () {
      final female = parse('seed=1&balls=$two,${custom({'x': 'female'})}')!;
      expect(female.contestants.last.gender, BallGender.female);
      final none = parse('seed=1&balls=$two,${custom({})}')!;
      expect(none.contestants.last.gender, BallGender.none);
      expect(parse('seed=1&balls=$two,${custom({'x': 'robot'})}'), isNull);
      expect(parse('seed=1&balls=$two,${custom({'x': 'none'})}'), isNull);
      expect(parse('seed=1&balls=$two,${custom({'x': 3})}'), isNull);

      final ids = {for (final b in _presets) b.id};
      const app = 'https://dbsuarez.github.io/ballwars/';
      const male = CustomBall(
        id: 'mine',
        name: 'Juan',
        primaryColor: Color(0xFF112233),
        glowColor: Color(0xFF445566),
        gender: BallGender.male,
      );
      const plain = CustomBall(
        id: 'mine2',
        name: 'Ana',
        primaryColor: Color(0xFF112233),
        glowColor: Color(0xFF445566),
      );
      final uri = ReplayLink(
        seed: 3,
        speedMultiplier: 1,
        contestants: [male, plain],
      ).toUri(presetIds: ids, appUrl: app);
      final parsed = ReplayLink.fromUri(uri, presets: _presets)!;
      expect(parsed.contestants.map((b) => b.gender), [
        BallGender.male,
        BallGender.none,
      ]);
      // None is left out, so links of balls without a gender are unchanged.
      final token = uri.queryParameters['balls']!.split(',').last.substring(2);
      final json = utf8.decode(
        base64Url.decode(token.padRight((token.length + 3) ~/ 4 * 4, '=')),
      );
      expect(json, isNot(contains('"x"')));
    });

    test('oversized links are rejected before parsing', () {
      expect(
        parse('seed=1&balls=$two&pad=${'a' * ReplayLink.maxLinkLength}'),
        isNull,
      );
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
    expect(uri.queryParameters['balls'], startsWith('v.4,m.allout,'));
    final parsed = ReplayLink.fromUri(uri, presets: _presets)!;
    expect(parsed.mode, MatchMode.allOut);
    expect(parsed.contestants, hasLength(2));

    final threads = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
    ).toUri(presetIds: ids, appUrl: app);
    expect(threads.queryParameters['balls'], isNot(contains('m.')));
  });

  test('an unknown mode token is rejected', () {
    ReplayLink? parse(String balls) => ReplayLink.fromUri(
      Uri.parse('https://x/?seed=1&balls=$balls'),
      presets: _presets,
    );
    final two = 'p.${_presets[0].id},p.${_presets[1].id}';
    expect(parse('m.laser,$two'), isNull);
    expect(parse(two)!.mode, MatchMode.threads);
    expect(parse('m.arsenal,$two')!.mode, MatchMode.arsenal);
    // Old '#/replay?' links carry the mode the same way.
    final legacy = ReplayLink.fromUri(
      Uri.parse('https://x/#/replay?seed=1&balls=m.allout,$two'),
      presets: _presets,
    );
    expect(legacy!.mode, MatchMode.allOut);
    expect(legacy.contestants.length, 2);
  });

  test(
    'ball size travels in the link; old links are medium; unknown sizes are rejected',
    () {
      final link = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        ballSize: BallSize.large,
      );
      final uri = link.toUri(
        presetIds: {for (final b in _presets) b.id},
        appUrl: 'https://dbsuarez.github.io/ballwars/',
      );
      expect(uri.queryParameters['size'], 'l');
      expect(
        ReplayLink.fromUri(uri, presets: _presets)!.ballSize,
        BallSize.large,
      );

      final medium =
          ReplayLink(
            seed: 5,
            speedMultiplier: 1,
            contestants: [_presets[0], _presets[1]],
          ).toUri(
            presetIds: {for (final b in _presets) b.id},
            appUrl: 'https://dbsuarez.github.io/ballwars/',
          );
      expect(medium.queryParameters.containsKey('size'), isFalse);
      expect(
        ReplayLink.fromUri(medium, presets: _presets)!.ballSize,
        BallSize.medium,
      );

      final bad = uri.replace(
        queryParameters: {...uri.queryParameters, 'size': 'huge'},
      );
      expect(ReplayLink.fromUri(bad, presets: _presets), isNull);
    },
  );

  test('dual wield travels in power-up replay links', () {
    final link = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      mode: MatchMode.arsenal,
      dualWield: true,
    );
    final uri = link.toUri(
      presetIds: {for (final b in _presets) b.id},
      appUrl: 'https://dbsuarez.github.io/ballwars/',
    );
    expect(uri.queryParameters['dw'], '1');
    expect(ReplayLink.fromUri(uri, presets: _presets)!.dualWield, isTrue);
  });

  test('a Yes or No question travels as q=, trimmed and on one line', () {
    final link = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      question: 'Will it rain?',
    );
    final uri = link.toUri(
      presetIds: {for (final b in _presets) b.id},
      appUrl: 'https://dbsuarez.github.io/ballwars/',
    );
    expect(uri.queryParameters['q'], 'Will it rain?');
    expect(
      ReplayLink.fromUri(uri, presets: _presets)!.question,
      'Will it rain?',
    );

    final none =
        ReplayLink(
          seed: 5,
          speedMultiplier: 1,
          contestants: [_presets[0], _presets[1]],
        ).toUri(
          presetIds: {for (final b in _presets) b.id},
          appUrl: 'https://dbsuarez.github.io/ballwars/',
        );
    expect(none.queryParameters.containsKey('q'), isFalse);
    expect(ReplayLink.fromUri(none, presets: _presets)!.question, isNull);

    final messy = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'q': '  Line one\nline two  ${'x' * 200}',
      },
    );
    final q = ReplayLink.fromUri(messy, presets: _presets)!.question!;
    expect(q.contains('\n'), isFalse);
    expect(q.length, lessThanOrEqualTo(100));
  });

  test(
    'chosen power-ups travel as a w. token; all chosen adds none; bad tokens are rejected',
    () {
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
      expect(tokens[0], 'v.4');
      expect(tokens[1], 'm.arsenal');
      expect(tokens[2], startsWith('w.'));
      expect(ReplayLink.fromUri(some, presets: _presets)!.powerUps, {
        PowerUpKind.knife,
        PowerUpKind.mine,
      });

      final all = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.arsenal,
      ).toUri(presetIds: ids, appUrl: app);
      expect(all.queryParameters['balls']!.contains('w.'), isFalse);
      expect(ReplayLink.fromUri(all, presets: _presets)!.powerUps, isNull);

      ReplayLink? withBalls(String balls) => ReplayLink.fromUri(
        Uri.parse('$app?seed=1&balls=$balls'),
        presets: _presets,
      );
      final a = 'p.${_presets[0].id}';
      final b = 'p.${_presets[1].id}';
      expect(
        withBalls('w.3,$a,$b'),
        isNull,
        reason: 'w. needs a power-up mode',
      );
      expect(
        withBalls('m.arsenal,w.0,$a,$b'),
        isNull,
        reason: 'empty selection',
      );
      expect(
        withBalls(
          'm.arsenal,w.${(BigInt.one << PowerUpKind.values.length).toRadixString(36)},$a,$b',
        ),
        isNull,
        reason: 'bits beyond the known kinds',
      );
    },
  );

  test(
    'power-up numbers travel in the link; threads links and bad values are rejected',
    () {
      final tuning = PowerUpConfig.defaults
          .withValue('dmg.pistol', 33)
          .withValue('aim', 0.5);
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

      // Default rarity assignments and weights still travel with new replays.
      final plain = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.arsenal,
      ).toUri(presetIds: {for (final b in _presets) b.id});
      expect(plain.queryParameters.containsKey('t'), isTrue);
      expect(
        ReplayLink.fromUri(plain, presets: _presets)!.tuning,
        PowerUpConfig.defaults,
      );

      final two = 'p.${_presets[0].id},p.${_presets[1].id}';
      ReplayLink? parse(String query) =>
          ReplayLink.fromUri(Uri.parse('https://x/?$query'), presets: _presets);
      expect(
        parse('seed=1&t=${tuning.encode()}&balls=$two'),
        isNull,
        reason: 'threads match with numbers',
      );
      expect(parse('seed=1&t=garbage!&balls=m.arsenal,$two'), isNull);
      expect(
        parse(
          'seed=1&t=${PowerUpConfig(const {'dmg.pistol': 5000}).encode()}&balls=m.arsenal,$two',
        ),
        isNull,
      );
    },
  );

  test('Endless Battle travels only with Arsenal replay links', () {
    final link = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      mode: MatchMode.arsenal,
      endlessBattle: true,
    );
    final uri = link.toUri(presetIds: {for (final b in _presets) b.id});
    expect(uri.queryParameters['endless'], '1');
    expect(ReplayLink.fromUri(uri, presets: _presets)!.endlessBattle, isTrue);

    final balls = 'p.${_presets[0].id},p.${_presets[1].id}';
    expect(
      ReplayLink.fromUri(
        Uri.parse('https://x/?seed=1&endless=1&balls=$balls'),
        presets: _presets,
      ),
      isNull,
    );
  });

  test('Mayhem travels only as a six-ball Arsenal replay', () {
    final six = List.generate(
      ReplayLink.mayhemBalls,
      (index) => CustomBall(
        id: 'mayhem-$index',
        name: 'Mayhem $index',
        primaryColor: Color(0xFF100000 + index),
        glowColor: Color(0xFF200000 + index),
        baseSpeed: 300,
        mass: 1,
      ),
    );
    final link = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: six,
      mode: MatchMode.arsenal,
      endlessBattle: true,
      mayhem: true,
      mayhemSeconds: 300,
    );
    final ids = {for (final ball in six) ball.id};
    final uri = link.toUri(presetIds: ids);
    expect(uri.queryParameters['mayhem'], '1');
    final restored = ReplayLink.fromUri(uri, presets: six)!;
    expect(restored.mayhem, isTrue);
    expect(restored.mayhemSeconds, 300);
    for (final bad in ['0', '-30', 'oops', '1801']) {
      expect(
        ReplayLink.fromUri(
          uri.replace(
            queryParameters: {...uri.queryParameters, 'duration': bad},
          ),
          presets: six,
        ),
        isNull,
      );
    }
    expect(restored.contestants, hasLength(ReplayLink.mayhemBalls));

    final two = 'p.${_presets[0].id},p.${_presets[1].id}';
    expect(
      ReplayLink.fromUri(
        Uri.parse('https://x/?seed=1&mayhem=1&balls=m.arsenal,$two'),
        presets: _presets,
      ),
      isNull,
    );
    expect(
      ReplayLink.fromUri(
        Uri.parse('https://x/?seed=1&mayhem=1&balls=$two'),
        presets: _presets,
      ),
      isNull,
    );
  });

  test('Shrinking arena travels in replay links', () {
    final link = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      shrinkingArena: true,
      minimumArenaScale: 0.45,
    );
    final uri = link.toUri(presetIds: {for (final b in _presets) b.id});
    expect(uri.queryParameters['shrink'], '1');
    expect(uri.queryParameters['minarena'], '0.45');
    final decoded = ReplayLink.fromUri(uri, presets: _presets)!;
    expect(decoded.shrinkingArena, isTrue);
    expect(decoded.minimumArenaScale, 0.45);
  });

  test('custom skill definitions are immutable replay snapshots', () {
    final draft = SkillLibrary.defaults.create(
      'Replay Bolt',
      PowerUpKind.pistol,
    );
    final original = SkillLibrary.defaults.withDefinition(
      draft.copyWith(enabled: true, arsenalDamage: 37, yell: 'SNAPSHOT!'),
      PowerUpConfig.defaults,
    );
    final uri = ReplayLink(
      seed: 9,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      mode: MatchMode.arsenal,
      skillLibrary: original,
    ).toUri(presetIds: _presetIds);

    final restored = ReplayLink.fromUri(uri, presets: _presets)!;
    final skill = restored.skillLibrary.byId(draft.id, PowerUpConfig.defaults)!;
    expect(skill.name, 'Replay Bolt');
    expect(skill.arsenalDamage, 37);
    expect(skill.yell, 'SNAPSHOT!');

    final changed = original.withDefinition(
      skill.copyWith(arsenalDamage: 99, yell: 'CHANGED!'),
      PowerUpConfig.defaults,
    );
    expect(changed.byId(draft.id, PowerUpConfig.defaults)!.arsenalDamage, 99);
    expect(
      restored.skillLibrary
          .byId(draft.id, PowerUpConfig.defaults)!
          .arsenalDamage,
      37,
    );
  });

  test('old links use default skills and malformed snapshots are rejected', () {
    final old = Uri.parse(
      'https://x/?seed=1&balls=m.arsenal,p.${_presets[0].id},p.${_presets[1].id}',
    );
    expect(
      ReplayLink.fromUri(old, presets: _presets)!.skillLibrary.isDefault,
      isTrue,
    );
    expect(
      ReplayLink.fromUri(
        old.replace(
          queryParameters: {...old.queryParameters, 'skills': 'broken'},
        ),
        presets: _presets,
      ),
      isNull,
    );
  });

  test(
    'the ball look travels in the link, so a replay shows the faces it was played with',
    () {
      final presetIds = {for (final b in _presets) b.id};
      final faces = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        look: BallLook.faces,
      ).toUri(presetIds: presetIds);
      expect(faces.queryParameters['look'], 'faces');
      expect(
        ReplayLink.fromUri(faces, presets: _presets)!.look,
        BallLook.faces,
      );

      // Older links have no look (the viewer's own setting applies); a garbled one is ignored, not fatal.
      final old = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
      ).toUri(presetIds: presetIds);
      expect(old.queryParameters.containsKey('look'), isFalse);
      expect(ReplayLink.fromUri(old, presets: _presets)!.look, isNull);
      final garbled = old.replace(
        queryParameters: {...old.queryParameters, 'look': 'sparkles'},
      );
      final parsed = ReplayLink.fromUri(garbled, presets: _presets);
      expect(parsed, isNotNull);
      expect(parsed!.look, isNull);
    },
  );

  test(
    'the chosen custom skills travel in the link; bad ids and threads links are rejected',
    () {
      final presetIds = {for (final b in _presets) b.id};
      final link = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.arsenal,
        customSkills: const {'custom.knife-volley', 'custom.boom-merang'},
      ).toUri(presetIds: presetIds);
      expect(
        link.queryParameters['cs'],
        'custom.boom-merang,custom.knife-volley',
      );
      expect(ReplayLink.fromUri(link, presets: _presets)!.customSkills, {
        'custom.knife-volley',
        'custom.boom-merang',
      });

      final none = link.replace(
        queryParameters: {...link.queryParameters, 'cs': ''},
      );
      expect(
        ReplayLink.fromUri(none, presets: _presets)!.customSkills,
        isEmpty,
      );
      final all = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.arsenal,
      ).toUri(presetIds: presetIds);
      expect(all.queryParameters.containsKey('cs'), isFalse);
      expect(ReplayLink.fromUri(all, presets: _presets)!.customSkills, isNull);

      final bad = link.replace(
        queryParameters: {...link.queryParameters, 'cs': 'builtin.pistol'},
      );
      expect(ReplayLink.fromUri(bad, presets: _presets), isNull);
      final threads = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
      ).toUri(presetIds: presetIds);
      final threadsWithCs = threads.replace(
        queryParameters: {...threads.queryParameters, 'cs': 'custom.x'},
      );
      expect(ReplayLink.fromUri(threadsWithCs, presets: _presets), isNull);
    },
  );

  test('Unstuck nudges travel in the link; bad values are rejected', () {
    final presetIds = {for (final b in _presets) b.id};
    final link = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
      nudgeSteps: const [121, 640],
    ).toUri(presetIds: presetIds);
    expect(link.queryParameters['nudge'], '121,640');
    expect(ReplayLink.fromUri(link, presets: _presets)!.nudgeSteps, [121, 640]);
    final plain = ReplayLink(
      seed: 5,
      speedMultiplier: 1,
      contestants: [_presets[0], _presets[1]],
    ).toUri(presetIds: presetIds);
    expect(plain.queryParameters.containsKey('nudge'), isFalse);
    expect(ReplayLink.fromUri(plain, presets: _presets)!.nudgeSteps, isEmpty);
    final late = link.replace(
      queryParameters: {...link.queryParameters, 'nudge': '121,200000'},
    );
    expect(ReplayLink.fromUri(late, presets: _presets)!.nudgeSteps, [
      121,
      200000,
    ]);
    for (final bad in ['x', '0', '-3', '216001', '99999999', '12,,40']) {
      final uri = link.replace(
        queryParameters: {...link.queryParameters, 'nudge': bad},
      );
      expect(ReplayLink.fromUri(uri, presets: _presets), isNull, reason: bad);
    }
  });

  test(
    'End battle step travels with endless links; bad values are rejected',
    () {
      final presetIds = {for (final b in _presets) b.id};
      final link = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.arsenal,
        endlessBattle: true,
        endStep: 900,
      ).toUri(presetIds: presetIds);
      expect(link.queryParameters['end'], '900');
      expect(ReplayLink.fromUri(link, presets: _presets)!.endStep, 900);
      final plain = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.arsenal,
        endlessBattle: true,
      ).toUri(presetIds: presetIds);
      expect(plain.queryParameters.containsKey('end'), isFalse);
      expect(ReplayLink.fromUri(plain, presets: _presets)!.endStep, isNull);
      final late = link.replace(
        queryParameters: {...link.queryParameters, 'end': '200000'},
      );
      expect(ReplayLink.fromUri(late, presets: _presets)!.endStep, 200000);
      for (final bad in ['x', '0', '-3', '216001', '1,2']) {
        final uri = link.replace(
          queryParameters: {...link.queryParameters, 'end': bad},
        );
        expect(ReplayLink.fromUri(uri, presets: _presets), isNull, reason: bad);
      }
      final notEndless = Map.of(link.queryParameters)..remove('endless');
      expect(
        ReplayLink.fromUri(
          link.replace(queryParameters: notEndless),
          presets: _presets,
        ),
        isNull,
      );
      // Not written outside endless battles.
      final threads = ReplayLink(
        seed: 5,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        endStep: 900,
      ).toUri(presetIds: presetIds);
      expect(threads.queryParameters.containsKey('end'), isFalse);
    },
  );

  group('kind count (kc) keeps old links playing as they were', () {
    final a = 'p.${_presets[0].id}';
    final b = 'p.${_presets[1].id}';

    test('a link from before kc opens with the first 48 kinds only', () {
      final link = ReplayLink.fromUri(
        Uri.parse(
          'https://x.test/?seed=3&speed=1&t=${_legacyTuning()}&balls=m.arsenal,$a,$b',
        ),
        presets: _presets,
      )!;
      expect(link.powerUps, {
        for (final k in PowerUpKind.values)
          if (k.index < ReplayLink.legacyKindCount) k,
      });
      expect(link.powerUps, isNot(contains(PowerUpKind.shadowClone)));
      // Recorded with the app at the commit before Shadow Clone (same seeds, all kinds on).
      const recorded = {
        3: 'boomerang,orbitingFlail,bow,busterSword,magneticField,busterSword',
        11: 'busterSword,knife,sniperRifle',
        29: 'busterSword,busterSword,sword,bow',
      };
      for (final entry in recorded.entries) {
        final old = ReplayLink.fromUri(
          Uri.parse(
            'https://x.test/?seed=${entry.key}&speed=1&t=${_legacyTuning()}&balls=m.arsenal,$a,$b',
          ),
          presets: _presets,
        )!;
        expect(
          _spawnedKinds(old).join(','),
          entry.value,
          reason: 'seed ${entry.key}',
        );
      }
    });

    test(
      'an old-format w. mask still parses; bits past its kinds are rejected',
      () {
        // pistol (bit 0) | knife (bit 3) = 9, as the app wrote it before kc.
        final link = ReplayLink.fromUri(
          Uri.parse('https://x.test/?seed=3&speed=1&balls=m.arsenal,w.9,$a,$b'),
          presets: _presets,
        )!;
        expect(link.powerUps, {PowerUpKind.pistol, PowerUpKind.knife});
        final clone = (BigInt.one << PowerUpKind.shadowClone.index)
            .toRadixString(36);
        expect(
          ReplayLink.fromUri(
            Uri.parse(
              'https://x.test/?seed=3&speed=1&balls=m.arsenal,w.$clone,$a,$b',
            ),
            presets: _presets,
          ),
          isNull,
          reason: 'Shadow Clone did not exist before kc',
        );
      },
    );

    test('w. masks past bit 31 are exact (BigInt, safe on the web)', () {
      final kinds = {
        PowerUpKind.values[33],
        PowerUpKind.values[40],
        PowerUpKind.values[48],
      };
      final expected =
          ((BigInt.one << 33) | (BigInt.one << 40) | (BigInt.one << 48))
              .toRadixString(36);
      final uri = ReplayLink(
        seed: 4,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.arsenal,
        powerUps: kinds,
      ).toUri(presetIds: _presetIds);
      expect(uri.queryParameters['balls']!.split(',')[2], 'w.$expected');
      expect(ReplayLink.fromUri(uri, presets: _presets)!.powerUps, kinds);
    });

    test('new links carry kc and round-trip with every kind', () {
      final uri = ReplayLink(
        seed: 4,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
        mode: MatchMode.allOut,
      ).toUri(presetIds: _presetIds);
      expect(uri.queryParameters['kc'], '${PowerUpKind.values.length}');
      final parsed = ReplayLink.fromUri(uri, presets: _presets)!;
      expect(parsed.powerUps, isNull, reason: 'all kinds: no RNG change');
      final threads = ReplayLink(
        seed: 4,
        speedMultiplier: 1,
        contestants: [_presets[0], _presets[1]],
      ).toUri(presetIds: _presetIds);
      expect(threads.queryParameters.containsKey('kc'), isFalse);
    });

    test('a pinned pool re-shares as the same pool', () {
      final old = ReplayLink.fromUri(
        Uri.parse('https://x.test/?seed=3&speed=1&balls=m.arsenal,$a,$b'),
        presets: _presets,
      )!;
      final again = ReplayLink.fromUri(
        ReplayLink(
          seed: old.seed,
          speedMultiplier: 1,
          contestants: old.contestants,
          mode: old.mode,
          powerUps: old.powerUps,
        ).toUri(presetIds: _presetIds),
        presets: _presets,
      )!;
      expect(again.powerUps, old.powerUps);
    });

    test('bad kc values are rejected', () {
      ReplayLink? withKc(String kc, {String mode = 'm.arsenal,'}) =>
          ReplayLink.fromUri(
            Uri.parse('https://x.test/?seed=3&speed=1&kc=$kc&balls=$mode$a,$b'),
            presets: _presets,
          );
      expect(withKc('${PowerUpKind.values.length}'), isNotNull);
      expect(withKc('${ReplayLink.firstLinkKindCount - 1}'), isNull);
      expect(withKc('${PowerUpKind.values.length + 1}'), isNull);
      expect(withKc('0'), isNull);
      expect(withKc('abc'), isNull);
      expect(withKc('048'), isNull);
      expect(withKc('49', mode: ''), isNull, reason: 'threads has no kinds');
    });

    test('t= tier lists longer than the kinds or empty are rejected', () {
      String tiers(String value) {
        final json = {'_tiers': value};
        return base64Url
            .encode(utf8.encode(jsonEncode(json)))
            .replaceAll('=', '');
      }

      final full = PowerUpKind.values.map((k) => k.isTrap ? '-' : '0').join();
      expect(PowerUpConfig.decode(tiers(full)), isNotNull);
      expect(PowerUpConfig.decode(tiers(full.substring(0, 48))), isNotNull);
      expect(PowerUpConfig.decode(tiers('${full}0')), isNull);
      expect(PowerUpConfig.decode(tiers('')), isNull);
      expect(
        PowerUpConfig.decode(
          tiers(full.substring(0, 48)),
        )!.rarityOf(PowerUpKind.shadowClone),
        PowerUpRarity.special,
      );
    });
  });
}

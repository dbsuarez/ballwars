import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arenas/domain/arena_catalog.dart';
import 'package:ballwars/features/arenas/domain/arena_theme.dart';
import 'package:ballwars/features/arenas/domain/arena_geometry.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';
import 'package:ballwars/features/replay_export/domain/replay_document.dart';

const arena = ArenaDefinition(
  id: 'golden-court',
  name: 'Golden Court',
  theme: ArenaDecoration.desert,
  trapTheme: ArenaDecoration.neonGrid,
  shape: ArenaShape.square,
  obstacle: CenterObstacle.circle,
  obstacleScale: .3,
  floorColor: 0xffab5522,
  accentColor: 0xffffcc44,
  rimColor: 0xffeeeeee,
);
void main() {
  test('background maps use a version gate to protect against old-client edits', () {
    final map=ArenaDefinition.fromJson({...arena.toJson(),'version':2,'background':'custom.test-background.background'});
    expect(map.toJson()['version'],2);
    expect(map.backgroundSpriteId,'custom.test-background.background');
    expect(()=>ArenaDefinition.fromJson({...map.toJson(),'version':1}),throwsFormatException);
    expect(arena.toJson()['version'],1);
  });

  test('replay geometry retains exact obstacle precision', () {
    final presets = LocalBallRepository.presets;
    const scale = 0.30000000000000004;
    final link = ReplayLink(
      contestants: presets.take(2).toList(),
      seed: 1,
      speedMultiplier: 1,
      simulationRevision: 8,
      centerObstacle: CenterObstacle.circle,
      centerObstacleScale: scale,
    );
    final replay = ReplayLink.fromUri(
      link.toUri(presetIds: {for (final b in presets) b.id}),
      presets: presets,
    )!;
    expect(replay.centerObstacleScale, scale);
  });

  test('catalog validates geometry, names, limits and defaults', () {
    final catalog = const ArenaCatalog().withArena(arena).withDefault(arena.id);
    expect(
      ArenaCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())),
      ).matchesStored(catalog.toJson()),
      isTrue,
    );
    expect(catalog.without(arena.id).defaultId, isNull);
    expect(catalog.without(arena.id).arenas, isEmpty);
    for (final bad in [double.nan, double.infinity, .11, .35]) {
      expect(
        () =>
            ArenaDefinition.fromJson({...arena.toJson(), 'obstacleScale': bad}),
        throwsFormatException,
      );
    }
    for (final bad in ['', ' x\ny', List.filled(41, 'x').join()]) {
      expect(
        () => ArenaDefinition.fromJson({...arena.toJson(), 'name': bad}),
        throwsFormatException,
      );
    }
    expect(
      () => ArenaDefinition.fromJson({...arena.toJson(), 'version': 4}),
      throwsFormatException,
    );
    final duplicate = ArenaDefinition.fromJson({
      ...arena.toJson(),
      'id': 'different',
    });
    expect(() => catalog.withArena(duplicate), throwsFormatException);
    expect(
      () => ArenaCatalog.fromJson({
        'version': 1,
        'arenas': [
          for (var i = 0; i < 33; i++)
            {...arena.toJson(), 'id': 'map-$i', 'name': 'Map $i'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => ArenaDefinition.fromJson({...arena.toJson(), 'floor': 0x00112233}),
      throwsFormatException,
    );
    expect(
      ArenaDefinition.fromJson({
        ...arena.toJson(),
        'name': List.filled(40, '\u{1f30d}').join(),
      }).name,
      isNotEmpty,
    );
  });
  test(
    'replay files embed immutable arena data after catalog edit or deletion',
    () {
      final presets = LocalBallRepository.presets;
      final link = ReplayLink(
        contestants: presets.take(2).toList(),
        seed: 71,
        speedMultiplier: 1,
        simulationRevision: 9,
        arenaPreset: arena,
        arenaDecoration: arena.trapTheme,
        arenaShape: arena.shape,
        centerObstacle: arena.obstacle,
        centerObstacleScale: arena.obstacleScale,
      );
      final uri = link.toUri(presetIds: {for (final b in presets) b.id});
      final document = ReplayDocument.decode(
        ReplayDocument(uri.queryParameters).encode(),
      );
      final replay = ReplayLink.fromUri(
        Uri(queryParameters: document.query),
        presets: presets,
      )!;
      final catalog = const ArenaCatalog().withArena(arena);
      final edited = catalog.withArena(
        ArenaDefinition.fromJson({
          ...arena.toJson(),
          'name': 'Changed',
          'floor': 0xff223344,
        }),
      );
      expect(edited.find(arena.id)!.name, 'Changed');
      expect(edited.without(arena.id).find(arena.id), isNull);
      expect(replay.arenaPreset!.toJson(), arena.toJson());
      expect(replay.arenaShape, ArenaShape.square);
      for (final bad in ['bad!', List.filled(2049, 'a').join()]) {
        expect(
          ReplayLink.fromUri(
            uri.replace(queryParameters: {...uri.queryParameters, 'map': bad}),
            presets: presets,
          ),
          isNull,
        );
      }
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/sprites/application/skill_sprite_readiness.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/sprites/application/custom_sprite_loader.dart';

class BlockingLoader extends CustomSpriteLoader {
  BlockingLoader() : super(null);
  final pending = Completer<void>();
  int reads = 0;
  @override
  bool get isLoading => true;
  @override
  Future<void> load() {
    reads++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ready match art never waits for unrelated library downloads', () async {
    final loader = BlockingLoader();
    SkillSpriteReadiness.loader = loader;
    addTearDown(() {
      loader.pending.complete();
      SkillSpriteReadiness.loader = null;
      SpriteRegistry.unregister('custom.ready');
    });
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    picture.dispose();
    await SpriteRegistry.register(
      const SpriteAtlas(
        sheet: 'ready.png',
        sprites: {
          'item': SpriteDef(
            id: 'item',
            frames: [ui.Rect.fromLTWH(0, 0, 8, 8)],
            output: 8,
            padding: 0,
            bleedOk: true,
            bleedNote: 'Single image',
          ),
        },
      ),
      image,
      idPrefix: 'custom.ready',
    );
    image.dispose();
    final missing = await SkillSpriteReadiness.prepare(
      library: SkillLibrary.defaults,
      tuning: PowerUpConfig.defaults,
      kinds: {},
      customIds: {},
      includeTraps: false,
      extraIds: ['custom.ready.item'],
    ).timeout(const Duration(seconds: 1));
    expect(missing, isEmpty);
    expect(loader.reads, 0);
  });
  test(
    'no held artwork is a presentation choice, not a missing asset',
    () async {
      const hidden = SkillDefinition(
        id: 'custom.unarmed-cast',
        name: 'Unarmed cast',
        custom: true,
        baseKind: PowerUpKind.energyWave,
        heldSpriteId: SkillDefinition.noHeldArtwork,
      );
      const library = SkillLibrary(custom: [hidden]);
      expect(library.activeSpriteReferences(hidden), isEmpty);
      expect(
        await SkillSpriteReadiness.prepare(
          library: library,
          tuning: PowerUpConfig.defaults,
          kinds: {},
          customIds: {hidden.id},
          includeTraps: false,
        ),
        isEmpty,
      );
      expect(hidden.effectiveHeldSpriteId, SkillDefinition.noHeldArtwork);
      final armed = hidden.copyWith(heldSpriteId: 'custom.missing.held');
      expect(library.activeSpriteReferences(armed), {'custom.missing.held'});
    },
  );

  test('dependencies include payloads but exclude unrelated custom skills', () {
    final payload = SkillDefinition(
      id: 'custom.payload',
      name: 'Payload',
      custom: true,
      baseKind: PowerUpKind.boomerang,
      projectileSpriteId: 'custom.sheet.projectile',
      impactSpriteId: 'custom.sheet.hit',
    );
    final launcher = SkillDefinition(
      id: 'custom.launcher',
      name: 'Launcher',
      custom: true,
      baseKind: PowerUpKind.pistol,
      payloadSkillId: payload.id,
      castingSpriteId: 'custom.sheet.cast',
    );
    final unrelated = SkillDefinition(
      id: 'custom.other',
      name: 'Other',
      custom: true,
      baseKind: PowerUpKind.apple,
      iconSpriteId: 'custom.other.icon',
    );
    final library = SkillLibrary(custom: [launcher, payload, unrelated]);
    expect(
      SkillSpriteReadiness.dependencies(
        library: library,
        tuning: PowerUpConfig.defaults,
        kinds: {},
        customIds: {launcher.id},
      ),
      {'custom.sheet.projectile', 'custom.sheet.hit', 'custom.sheet.cast'},
    );
  });

  test('missing artwork is reported rather than silently accepted', () async {
    final previous = SkillSpriteReadiness.loader;
    SkillSpriteReadiness.loader = null;
    addTearDown(() => SkillSpriteReadiness.loader = previous);
    final library = SkillLibrary(
      custom: [
        const SkillDefinition(
          id: 'custom.a',
          name: 'A',
          custom: true,
          baseKind: PowerUpKind.knife,
          iconSpriteId: 'custom.missing.icon',
        ),
      ],
    );
    expect(
      await SkillSpriteReadiness.prepare(
        library: library,
        tuning: PowerUpConfig.defaults,
        kinds: {},
        customIds: {'custom.a'},
      ),
      {'custom.missing.icon'},
    );
  });
}

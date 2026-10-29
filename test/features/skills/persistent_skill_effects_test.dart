import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const tuning = PowerUpConfig.defaults;
const art = EffectDefinition(
  id: 'persistent',
  name: 'Persistent',
  spriteId: 'qa.phase-d',
  playback: EffectPlayback.loop,
);
SkillLibrary library({double scale = 1, double? duration, bool bound = true}) {
  var lib = SkillLibrary.defaults.withEffect(
    EffectDefinition(
      id: art.id,
      name: art.name,
      spriteId: art.spriteId,
      playback: art.playback,
      scale: scale,
      durationSeconds: duration,
    ),
  );
  for (final kind in PowerUpKind.values) {
    lib = lib.withDefinition(
      lib
          .builtIn(kind, tuning)
          .copyWith(
            visualBindings: bound
                ? {
                    for (final role in SkillVisualRole.values)
                      role: const SkillVisualBinding(effectId: 'persistent'),
                  }
                : {},
          ),
      tuning,
    );
  }
  return lib;
}

MatchSimulationController create({SkillLibrary? lib}) {
  final m = MatchSimulationController(
    const [
      CustomBall(
        id: 'a',
        name: 'A',
        primaryColor: Colors.red,
        glowColor: Colors.red,
      ),
      CustomBall(
        id: 'b',
        name: 'B',
        primaryColor: Colors.blue,
        glowColor: Colors.blue,
      ),
    ],
    arenaRadius: 180,
    mode: MatchMode.arsenal,
    seed: 44,
    lookAhead: false,
    automaticSpeedUp: false,
    skillLibrary: lib ?? library(),
  );
  m.powerUps!.automaticSpawning = false;
  m.powerUps!.automaticPassiveTriggers = false;
  m.state.balls.first
    ..position = const Offset(-65, 0)
    ..velocity = Offset.zero;
  m.state.balls.last
    ..position = const Offset(65, 0)
    ..velocity = Offset.zero;
  return m;
}

void pickup(MatchSimulationController m, PowerUpKind kind) =>
    m.powerUps!.pickUp(
      m.state.balls.first,
      FieldPowerUp(
        kind: kind,
        position: m.state.balls.first.position,
        spawnStep: 0,
      ),
    );

class RecordedCanvas extends Fake implements Canvas {
  final translations = <Offset>[];
  final sizes = <double>[];
  @override
  void translate(double x, double y) => translations.add(Offset(x, y));
  @override
  void drawImageRect(ui.Image image, Rect source, Rect target, Paint paint) =>
      sizes.add(target.width);
  @override
  Rect getLocalClipBounds() => const Rect.fromLTWH(-500, -500, 1000, 1000);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => Future<void>.sync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(
        recorder,
      ).drawCircle(const Offset(8, 8), 7, Paint()..color = Colors.green);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      await SpriteRegistry.registerDrawn('qa.phase-d', image, output: 16);
      image.dispose();
      picture.dispose();
    }),
  );
  test(
    'all persistent roles survive full/compact snapshots; Phase C remains readable',
    () {
      final lib = library();
      expect(lib.toJson()['version'], 8);
      expect(lib.toCompactJson()['version'], 9);
      for (final json in [lib.toJson(), lib.toCompactJson()]) {
        final loaded = SkillLibrary.importJson(jsonEncode(json));
        expect(
          loaded
              .builtIn(PowerUpKind.goldenArmor, tuning)
              .visualBindings
              .keys
              .toSet(),
          SkillVisualRole.values.toSet(),
        );
      }
      for (final (json, version) in [
        (lib.toJson(), 6),
        (lib.toCompactJson(), 7),
      ]) {
        json['version'] = version;
        expect(SkillLibrary.importJson(jsonEncode(json)).effects.length, 1);
      }
    },
  );
  test(
    'buff expiry uses actual timer and reapplication restarts its visual age',
    () {
      final m = create();
      final p = m.powerUps!, b = m.state.balls.first;
      pickup(m, PowerUpKind.speed);
      p.persistentEffects.sync();
      final first = p.persistentEffects.handles.singleWhere(
        (e) => e.role == SkillVisualRole.ownerStatus,
      );
      m.tick(1 / 60);
      expect(first.age, greaterThan(0));
      b.speedLeft = 2;
      p.persistentEffects.sync();
      pickup(m, PowerUpKind.speed);
      p.persistentEffects.sync();
      final refreshed = p.persistentEffects.handles.singleWhere(
        (e) => e.role == SkillVisualRole.ownerStatus,
      );
      expect(identical(first, refreshed), isFalse);
      expect(refreshed.age, 0);
      b.speedLeft = 1;
      m.tick(1 / 60);
      expect(
        p.persistentEffects.handles.where(
          (e) => e.role == SkillVisualRole.ownerStatus,
        ),
        isEmpty,
      );
      expect(
        p.persistentEffects.events.where(
          (e) => e.role == SkillVisualRole.expiry,
        ),
        hasLength(1),
      );
    },
  );
  test(
    'short visual lifetime never restarts while its buff remains active',
    () {
      final m = create(lib: library(duration: 2 / 60)), p = m.powerUps!;
      pickup(m, PowerUpKind.speed);
      p.persistentEffects.sync();
      for (var i = 0; i < 5; i++) {
        m.tick(1 / 60);
      }
      expect(m.state.balls.first.speedLeft, greaterThan(0));
      final handle = p.persistentEffects.handles.singleWhere(
        (e) => e.role == SkillVisualRole.ownerStatus,
      );
      expect(handle.age, greaterThanOrEqualTo(5));
      final canvas = RecordedCanvas();
      PowerUpPainter.paintPersistentOverlays(
        canvas,
        p,
        EffectRenderMode.sprite,
      );
      expect(canvas.sizes, isEmpty);
    },
  );
  test('clearing a status while paused stops artwork before another step', () {
    final m = create(), p = m.powerUps!;
    pickup(m, PowerUpKind.speed);
    p.persistentEffects.sync();
    final before = RecordedCanvas();
    PowerUpPainter.paintPersistentOverlays(before, p, EffectRenderMode.sprite);
    expect(before.sizes, isNotEmpty);
    m.state.balls.first.speedLeft = 0;
    final after = RecordedCanvas();
    PowerUpPainter.paintPersistentOverlays(after, p, EffectRenderMode.sprite);
    expect(after.sizes, isEmpty);
    expect(
      PowerUpPainter.hasPersistentStatus(
        p,
        m.state.balls.first,
        PowerUpKind.speed,
        EffectRenderMode.sprite,
      ),
      isFalse,
    );
  });
  test('death and respawn clear status handles without expiry ghosts', () {
    final m = create(), p = m.powerUps!, b = m.state.balls.first;
    pickup(m, PowerUpKind.goldenArmor);
    p.persistentEffects.sync();
    p.resetForRespawn(b);
    p.persistentEffects.sync();
    expect(p.persistentEffects.handles, isEmpty);
    expect(p.persistentEffects.events, isEmpty);
    pickup(m, PowerUpKind.speed);
    p.persistentEffects.sync();
    b.life = 0;
    p.persistentEffects.sync();
    expect(p.persistentEffects.handles, isEmpty);
    expect(p.persistentEffects.events, isEmpty);
  });
  test(
    'actual armor hits emit block then break with custom skill identity',
    () {
      var lib = library();
      final custom = lib
          .builtIn(PowerUpKind.goldenArmor, tuning)
          .copyWith(id: 'custom.guard', name: 'Guard', custom: true);
      lib = lib.withDefinition(custom, tuning);
      final m = create(lib: lib), p = m.powerUps!, b = m.state.balls.first;
      p.pickUp(
        b,
        FieldPowerUp(
          kind: PowerUpKind.goldenArmor,
          skillId: custom.id,
          position: b.position,
          spawnStep: 0,
        ),
      );
      p.persistentEffects.sync();
      expect(m.damage(b, 10), 0);
      expect(b.goldenArmorHits, 1);
      expect(m.damage(b, 10), 0);
      expect(b.goldenArmorHits, 0);
      expect(
        p.persistentEffects.events.where(
          (e) => e.role == SkillVisualRole.block,
        ),
        hasLength(2),
      );
      expect(
        p.persistentEffects.events
            .where((e) => e.role == SkillVisualRole.breakage)
            .single
            .skill
            .id,
        custom.id,
      );
      expect(b.life, 100);
    },
  );
  test(
    'curved binding scales art without moving physical samples or collision',
    () {
      List<Offset> draw(double scale) {
        final m = create(lib: library(scale: scale)), p = m.powerUps!;
        final wall = SpikeWall(
          position: const Offset(170, 0),
          angle: 0,
          spawnStep: 0,
        );
        p.spikeWalls.add(wall);
        p.persistentEffects.sync();
        final before = wall.spikePositions(p.fieldRadius * .96);
        final canvas = RecordedCanvas();
        expect(
          PowerUpPainter.paintPersistentZone(
            canvas,
            p,
            wall,
            EffectRenderMode.sprite,
          ),
          isTrue,
        );
        expect(canvas.sizes, hasLength(6));
        expect(wall.spikePositions(p.fieldRadius * .96), before);
        expect(canvas.sizes.first, closeTo(2 * p.fieldRadius * scale, .01));
        return canvas.translations;
      }

      expect(draw(1), draw(3));
    },
  );
  test('ground follows source lifetime and explicit vector falls back', () {
    final m = create(), p = m.powerUps!;
    final zone = BurningZone(
      owner: m.state.balls.first,
      position: Offset.zero,
      radius: 50,
    );
    p.burningZones.add(zone);
    p.persistentEffects.sync();
    final canvas = RecordedCanvas();
    expect(
      PowerUpPainter.paintPersistentZone(
        canvas,
        p,
        zone,
        EffectRenderMode.sprite,
      ),
      isTrue,
    );
    expect(
      PowerUpPainter.paintPersistentZone(
        canvas,
        p,
        zone,
        EffectRenderMode.vector,
      ),
      isFalse,
    );
    zone.owner.life = 0;
    p.persistentEffects.sync();
    expect(p.persistentEffects.handles, hasLength(1));
    expect(
      PowerUpPainter.paintPersistentZone(
        canvas,
        p,
        zone,
        EffectRenderMode.sprite,
      ),
      isTrue,
    );
    p.burningZones.clear();
    p.persistentEffects.sync();
    expect(p.persistentEffects.handles, isEmpty);
    expect(p.persistentEffects.events.single.role, SkillVisualRole.expiry);
  });
  test('channel interruption ends both status and casting handles', () {
    final m = create(), p = m.powerUps!, b = m.state.balls.first;
    p.activateTestSkill(
      b,
      m.skillLibrary.builtIn(PowerUpKind.energyWave, tuning),
      m.state.balls.last,
    );
    m.tick(1 / 60);
    p.persistentEffects.sync();
    expect(p.energyWaveAttacks, isNotEmpty);
    expect(
      p.persistentEffects.handles.where(
        (e) => e.role == SkillVisualRole.ownerStatus,
      ),
      isNotEmpty,
    );
    p.energyWaveAttacks.clear();
    m.tick(1 / 60);
    expect(
      p.persistentEffects.handles.where(
        (e) => e.role == SkillVisualRole.ownerStatus,
      ),
      isEmpty,
    );
    expect(p.castingArtwork, isEmpty);
  });
  test('actual fired weapon discard emits once after its hold', () {
    final m = create(), p = m.powerUps!, b = m.state.balls.first;
    p.activateTestSkill(
      b,
      m.skillLibrary.builtIn(PowerUpKind.pistol, tuning),
      m.state.balls.last,
    );
    for (var i = 0; i < 65; i++) {
      m.tick(1 / 60);
    }
    expect(
      p.persistentEffects.history.where(
        (s) => s.contains('discard') && s.contains('Pistol'),
      ),
      hasLength(1),
    );
  });
  test('native Freeze follows the victim and clears on thaw', () {
    final m = create(), p = m.powerUps!, b = m.state.balls.last;
    p.activateTestSkill(
      m.state.balls.first,
      m.skillLibrary.builtIn(PowerUpKind.freeze, tuning),
      b,
    );
    for (var i = 0; i < 40; i++) {
      m.tick(1 / 60);
    }
    expect(b.frozenLeft, greaterThan(0));
    final handle = p.persistentEffects.handles.singleWhere(
      (e) => e.role == SkillVisualRole.targetStatus,
    );
    expect(handle.target, b);
    b.position = const Offset(20, 35);
    expect(handle.center(), b.position);
    expect(
      PowerUpPainter.hasPersistentStatus(
        p,
        b,
        PowerUpKind.freeze,
        EffectRenderMode.sprite,
      ),
      isTrue,
    );
    b.frozenLeft = 1;
    m.tick(1 / 60);
    expect(
      p.persistentEffects.handles.where(
        (e) => e.role == SkillVisualRole.targetStatus,
      ),
      isEmpty,
    );
  });
  test('composed stun uses its own binding and resets with the target', () {
    final base = library();
    final skill = SkillDefinition(
      id: 'custom.stun',
      name: 'Custom stun',
      baseKind: PowerUpKind.apple,
      custom: true,
      category: SkillCategory.powerUp,
      trigger: SkillTrigger.pickup,
      targeting: SkillTargeting.nearestOpponent,
      delivery: SkillDelivery.instant,
      effectType: SkillEffectType.stun,
      durationSeconds: 2,
      visualBindings: const {
        SkillVisualRole.targetStatus: SkillVisualBinding(
          effectId: 'persistent',
        ),
      },
    );
    final m = create(lib: base.withDefinition(skill, tuning)),
        p = m.powerUps!,
        b = m.state.balls.last;
    p.activateTestSkill(m.state.balls.first, skill, b);
    m.tick(1 / 60);
    final handle = p.persistentEffects.handles.singleWhere(
      (e) => e.role == SkillVisualRole.targetStatus,
    );
    expect(handle.skill.id, skill.id);
    expect(handle.target, b);
    expect(b.stunnedLeft, greaterThan(0));
    p.resetForRespawn(b);
    p.persistentEffects.sync();
    expect(p.persistentEffects.handles, isEmpty);
  });
  test('mirror reflection emits its block and final charge break', () {
    final m = create(), p = m.powerUps!, b = m.state.balls.first;
    pickup(m, PowerUpKind.mirror);
    p.activateTestSkill(
      m.state.balls.last,
      m.skillLibrary.builtIn(PowerUpKind.pistol, tuning),
      b,
    );
    for (var i = 0; i < 32; i++) {
      m.tick(1 / 60);
    }
    expect(b.mirrorCharges, 0);
    expect(
      p.persistentEffects.history.where(
        (s) =>
            s.contains('Mirror') && s.contains('block') && s.contains('event'),
      ),
      hasLength(1),
    );
    expect(
      p.persistentEffects.history.where(
        (s) => s.contains('Mirror') && s.contains('breakage'),
      ),
      hasLength(1),
    );
    expect(
      p.persistentEffects.history.where(
        (s) => s.contains('Mirror') && s.contains('expiry'),
      ),
      isEmpty,
    );
  });
  test('bound visuals do not alter deterministic damage, movement or RNG', () {
    final bound = create(), plain = create(lib: library(bound: false));
    for (final m in [bound, plain]) {
      pickup(m, PowerUpKind.speed);
      m.powerUps!.activateTestSkill(
        m.state.balls.first,
        m.skillLibrary.builtIn(PowerUpKind.pistol, tuning),
        m.state.balls.last,
      );
    }
    for (var i = 0; i < 180; i++) {
      bound.tick(1 / 60);
      plain.tick(1 / 60);
    }
    for (var i = 0; i < 2; i++) {
      expect(bound.state.balls[i].position, plain.state.balls[i].position);
      expect(bound.state.balls[i].life, plain.state.balls[i].life);
    }
    expect(bound.powerUps!.rng.nextDouble(), plain.powerUps!.rng.nextDouble());
  });
}

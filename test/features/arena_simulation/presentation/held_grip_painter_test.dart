import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_face_expression.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records rotations, flips, image centers and circle centers, following
/// translate/save/restore (rotation is only recorded, not applied).
class _RecordingCanvas implements Canvas {
  final List<double> rotations = [];
  final List<Offset> scales = [];
  final List<Offset> imageOrigins = [];
  final List<Offset> circles = [];
  final List<Offset> _stack = [];
  Offset _origin = Offset.zero;

  @override
  void save() => _stack.add(_origin);

  @override
  void restore() => _origin = _stack.removeLast();

  @override
  void translate(double dx, double dy) => _origin += Offset(dx, dy);

  @override
  void rotate(double radians) => rotations.add(radians);

  @override
  void scale(double sx, [double? sy]) => scales.add(Offset(sx, sy ?? sx));

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      imageOrigins.add(_origin);

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add(c + _origin);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

SimulationBall _ball({Offset velocity = const Offset(10, 0)}) => SimulationBall(
  config: const CustomBall(
    id: 'a',
    name: 'a',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  position: const Offset(100, 100),
  velocity: velocity,
  radius: 10,
  lineCount: 0,
);

Future<ui.Image> _square() {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
    const Rect.fromLTWH(0, 0, 16, 16),
    Paint()..color = const Color(0xFF00FF00),
  );
  return rec.endRecording().toImage(16, 16);
}

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-9));
  expect(actual.dy, closeTo(expected.dy, 1e-9));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(SpriteRegistry.resetForTest);

  test('grip sideways moves the held center across the aim', () {
    final ball = _ball()..equipWeapon(PowerUpKind.pistol, dualWield: false);
    final plain = PowerUpPainter.heldCenter(ball);
    expect(plain, const Offset(112, 100));
    _expectOffset(
      PowerUpPainter.heldCenter(ball, gripSide: 0.5),
      const Offset(112, 105),
    );
    _expectOffset(
      PowerUpPainter.heldCenter(ball, gripSide: -0.5),
      const Offset(112, 95),
    );

    // Facing left is a horizontal mirror: the weapon still moves down.
    final left = _ball(velocity: const Offset(-10, 0))
      ..equipWeapon(PowerUpKind.pistol, dualWield: false);
    _expectOffset(PowerUpPainter.heldCenter(left), const Offset(88, 100));
    _expectOffset(
      PowerUpPainter.heldCenter(left, gripSide: 0.5),
      const Offset(88, 105),
    );
  });

  test('the second hand mirrors grip sideways', () {
    final ball = _ball()
      ..equipWeapon(PowerUpKind.pistol, dualWield: true)
      ..equipWeapon(PowerUpKind.pistol, dualWield: true);
    expect(ball.heldSecondary, isNotNull);
    for (final slot in const [0, 1]) {
      final angle = PowerUpPainter.heldAngle(ball, slot: slot);
      final right = Offset(-math.sin(angle), math.cos(angle));
      final moved =
          PowerUpPainter.heldCenter(ball, slot: slot, gripSide: 0.5) -
          PowerUpPainter.heldCenter(ball, slot: slot);
      _expectOffset(moved, right * (slot == 0 ? 5 : -5));
    }
  });

  test('a negative grip forward/back pushes the weapon out along the aim', () {
    final ball = _ball()..equipWeapon(PowerUpKind.pistol, dualWield: false);
    expect(PowerUpPainter.heldCenter(ball), const Offset(112, 100));
    _expectOffset(
      PowerUpPainter.heldCenter(ball, gripInset: -0.5),
      const Offset(117, 100),
    );
    // 0..1.5 is unchanged (pulled in, never closer than 0.1 radii).
    _expectOffset(
      PowerUpPainter.heldCenter(ball, gripInset: 0.5),
      const Offset(107, 100),
    );
    _expectOffset(
      PowerUpPainter.heldCenter(ball, gripInset: 1.5),
      const Offset(101, 100),
    );
    // Clamped at -1.5.
    _expectOffset(
      PowerUpPainter.heldCenter(ball, gripInset: -9),
      const Offset(127, 100),
    );

    final left = _ball(velocity: const Offset(-10, 0))
      ..equipWeapon(PowerUpKind.pistol, dualWield: false);
    _expectOffset(
      PowerUpPainter.heldCenter(left, gripInset: -0.5),
      const Offset(83, 100),
    );

    final dual = _ball()
      ..equipWeapon(PowerUpKind.pistol, dualWield: true)
      ..equipWeapon(PowerUpKind.pistol, dualWield: true);
    for (final slot in const [0, 1]) {
      final far = PowerUpPainter.heldCenter(dual, slot: slot, gripInset: -0.5);
      final near = PowerUpPainter.heldCenter(dual, slot: slot);
      expect(
        (far - dual.position).distance - (near - dual.position).distance,
        closeTo(5, 1e-9),
      );
    }
  });

  test('the hand stays at the standard grip point whatever the grip', () {
    final ball = _ball()..equipWeapon(PowerUpKind.pistol, dualWield: false);
    final base = gripHandPosition(ball);
    _expectOffset(base, const Offset(107.5, 103));
    // The weapon moves; the marker/hand does not.
    _expectOffset(
      PowerUpPainter.heldCenter(ball, gripInset: -0.5),
      const Offset(117, 100),
    );
    final blade = _ball()..equipWeapon(PowerUpKind.knife, dualWield: false);
    // Blade default inset 0.2: center 18 - 13 = 5 ahead of the ball.
    _expectOffset(gripHandPosition(blade), const Offset(105, 100));
  });

  test('a shield ignores grip sideways', () {
    final ball = _ball()..equipWeapon(PowerUpKind.shield, dualWield: false);
    expect(
      PowerUpPainter.heldCenter(ball, gripSide: 1),
      PowerUpPainter.heldCenter(ball),
    );
  });

  test('the drawn sprite angle includes the grip rotation, mirrored when '
      'flipped', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final image = await _square();
      await SpriteRegistry.registerDrawn(
        PowerUpSprites.iconId(PowerUpKind.pistol),
        image,
        output: 32,
      );
      const rad = 30 * math.pi / 180;

      List<double> rotations(SimulationBall ball, double degrees) {
        final canvas = _RecordingCanvas();
        PowerUpPainter.paintBallEffects(
          canvas,
          ball,
          weaponGripRotation: (_, _) => degrees,
        );
        expect(canvas.imageOrigins, hasLength(1));
        return canvas.rotations;
      }

      final right = _ball()..equipWeapon(PowerUpKind.pistol, dualWield: false);
      expect(rotations(right, 0), isEmpty);
      final turned = rotations(right, 30);
      expect(turned.single, closeTo(rad, 1e-9));

      final left = _ball(velocity: const Offset(-10, 0))
        ..equipWeapon(PowerUpKind.pistol, dualWield: false);
      expect(rotations(left, 0).single, closeTo(math.pi, 1e-9));
      expect(rotations(left, 30).single, closeTo(math.pi - rad, 1e-9));
      image.dispose();
    });
  });

  test('the drawn sprite and badge follow grip sideways', () async {
    final noSprite = _ball()..equipWeapon(PowerUpKind.pistol, dualWield: false);
    final canvas = _RecordingCanvas();
    PowerUpPainter.paintBallEffects(
      canvas,
      noSprite,
      useWeaponSprite: (_, _) => false,
      weaponGripSide: (_, _) => 0.5,
    );
    _expectOffset(canvas.circles.first, const Offset(112, 105));

    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final image = await _square();
      await SpriteRegistry.registerDrawn(
        PowerUpSprites.iconId(PowerUpKind.pistol),
        image,
        output: 32,
      );
      final sprite = _RecordingCanvas();
      PowerUpPainter.paintBallEffects(
        sprite,
        noSprite,
        weaponGripSide: (_, _) => 0.5,
      );
      _expectOffset(sprite.imageOrigins.single, const Offset(112, 105));
      image.dispose();
    });
  });

  test('hands do not follow grip inset, sideways or rotation', () {
    List<Offset> hands(
      SimulationBall ball, {
      double inset = 0,
      double side = 0,
      double rotation = 0,
    }) {
      final canvas = _RecordingCanvas();
      paintHands(
        canvas,
        ball,
        weaponGripInset: (_, _) => inset,
        weaponGripSide: (_, _) => side,
        weaponGripRotation: (_, _) => rotation,
      );
      return canvas.circles;
    }

    void same(List<Offset> a, List<Offset> b) {
      expect(a, hasLength(b.length));
      for (var i = 0; i < a.length; i++) {
        _expectOffset(a[i], b[i]);
      }
    }

    final right = _ball()..equipWeapon(PowerUpKind.pistol, dualWield: false);
    // Default grip: center (112, 100) - dir * 4.5 + right * 3.
    _expectOffset(hands(right).first, const Offset(107.5, 103));
    same(hands(right, side: 0.5), hands(right));
    same(hands(right, inset: -0.5, rotation: 90), hands(right));

    final left = _ball(velocity: const Offset(-10, 0))
      ..equipWeapon(PowerUpKind.pistol, dualWield: false);
    _expectOffset(hands(left).first, const Offset(92.5, 103));
    same(hands(left, side: 0.5, inset: 1), hands(left));

    final dual = _ball()
      ..equipWeapon(PowerUpKind.pistol, dualWield: true)
      ..equipWeapon(PowerUpKind.pistol, dualWield: true);
    same(hands(dual, side: 0.5, rotation: 40, inset: -1), hands(dual));
  });
}

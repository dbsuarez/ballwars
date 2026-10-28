import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/hair_styles.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_hair_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

Future<Uint8List> _render(int? style) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  BallHairPainter.paint(
    canvas,
    SimulationBall(
      config: const CustomBall(
        id: 'x',
        name: 'X',
        primaryColor: Colors.teal,
        glowColor: Colors.white,
      ),
      position: const Offset(40, 44),
      velocity: Offset.zero,
      radius: 20,
      lineCount: 0,
      hairstyle: style,
      hairColor: const Color(0xFF4B2E20),
    ),
  );
  final image = await recorder.endRecording().toImage(80, 80);
  final data = await image.toByteData();
  return data!.buffer.asUint8List();
}

void main() {
  test('the male and female pools split every style between them', () {
    expect(
      {...BallHairPainter.maleStyles, ...BallHairPainter.femaleStyles},
      {for (var s = 0; s < HairStyles.count; s++) s},
    );
    expect(
      BallHairPainter.maleStyles.toSet().intersection(
        BallHairPainter.femaleStyles.toSet(),
      ),
      isEmpty,
    );
    // The five new families are all female.
    for (var s = HairStyles.legacyCount; s < HairStyles.count; s++) {
      expect(BallHairPainter.femaleStyles, contains(s));
    }
  });

  test('every style draws something, and each one looks different', () async {
    final seen = <String>{};
    for (var s = 0; s < HairStyles.count; s++) {
      final pixels = await _render(s);
      expect(pixels.any((b) => b != 0), isTrue, reason: 'style $s');
      expect(seen.add(String.fromCharCodes(pixels)), isTrue, reason: '$s');
    }
    expect((await _render(null)).every((b) => b == 0), isTrue);
  });

  test('styleFor: none keeps the shuffle; genders map into their pool', () {
    expect(HairStyles.styleFor(BallGender.none, 'a', null), isNull);
    expect(HairStyles.styleFor(BallGender.none, 'a', 7, seed: 3), 7);
    for (var order = 0; order < HairStyles.legacyCount; order++) {
      expect(
        HairStyles.female,
        contains(HairStyles.styleFor(BallGender.female, 'a', order, seed: 9)),
      );
      expect(
        HairStyles.male,
        contains(HairStyles.styleFor(BallGender.male, 'a', order, seed: 9)),
      );
    }
    expect(
      HairStyles.styleFor(BallGender.female, 'group:1', null),
      HairStyles.styleFor(BallGender.female, 'group:1', null),
    );
    // Across seeds the whole female pool shows up.
    expect({
      for (var seed = 0; seed < 40; seed++)
        HairStyles.styleFor(BallGender.female, 'a', 0, seed: seed),
    }, HairStyles.female.toSet());
  });

  test('styleFor moves past styles its gender already took', () {
    final first = HairStyles.styleFor(BallGender.male, 'a', 3, seed: 0)!;
    expect(
      HairStyles.styleFor(BallGender.male, 'a', 3, taken: {first}),
      isNot(first),
    );
    expect(
      HairStyles.styleFor(BallGender.male, 'a', 3, taken: {first}),
      HairStyles.male[(HairStyles.male.indexOf(first) + 1) %
          HairStyles.male.length],
    );
    // A full pool falls back to the first pick; None ignores taken.
    expect(
      HairStyles.styleFor(
        BallGender.male,
        'a',
        3,
        taken: HairStyles.male.toSet(),
      ),
      first,
    );
    expect(HairStyles.styleFor(BallGender.none, 'a', 7, taken: {7}), 7);
  });
}

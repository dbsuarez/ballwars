// Renders every hairstyle on a sample ball, in both looks, into one contact
// sheet for a visual check. Run:
//   flutter test tool/hair/render_hair_test.dart --dart-define=OUT=<file.png>
// Rows: picture look, then face look, per style (index printed above).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/hair_styles.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_face_expression.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_face_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_hair_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  test(
    'render hair contact sheet',
    () async {
      const cell = 150.0;
      const cols = 10;
      const radius = 40.0;
      final rows = (HairStyles.count / cols).ceil();
      final width = cols * cell;
      final height = rows * cell * 2;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF0A0A0B),
      );
      const config = CustomBall(
        id: 'sample',
        name: 'Maria',
        imageStyle: BallImageStyle.logo,
        primaryColor: Color(0xFF4FD1C5),
        glowColor: Color(0xFFA0E8E0),
      );
      for (var s = 0; s < HairStyles.count; s++) {
        for (final faces in [false, true]) {
          final col = s % cols;
          final row = (s ~/ cols) * 2 + (faces ? 1 : 0);
          final center = Offset(
            col * cell + cell / 2,
            row * cell + cell / 2 + 8,
          );
          final ball = SimulationBall(
            config: config,
            position: center,
            velocity: Offset.zero,
            radius: radius,
            lineCount: 0,
            hairstyle: s,
            hairColor: s.isEven
                ? const Color(0xFF4B2E20)
                : const Color(0xFFD6B46A),
          );
          if (faces) {
            paintSmiley(canvas, ball, 1, [ball]);
          } else {
            BallFacePainter.paint(canvas, center, radius, config, null);
          }
          BallHairPainter.paint(canvas, ball);
          final label = TextPainter(
            text: TextSpan(
              text: '$s${HairStyles.female.contains(s) ? ' F' : ' M'}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          label.paint(canvas, Offset(col * cell + 6, row * cell + 4));
        }
      }
      final image = await recorder.endRecording().toImage(
        width.toInt(),
        height.toInt(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(_out).writeAsBytesSync(png!.buffer.asUint8List());
    },
    skip: _out.isEmpty ? 'pass --dart-define=OUT=<file.png>' : false,
  );
}

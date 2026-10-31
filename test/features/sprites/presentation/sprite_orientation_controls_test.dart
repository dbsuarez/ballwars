import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_edit.dart';
import 'package:ballwars/features/sprites/presentation/sprite_editor_card.dart';

void main() {
  testWidgets('sprite editor offers rotation and both flip controls', (tester) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 16, 16),
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(16, 16);
    addTearDown(image.dispose);
    picture.dispose();
    final edit = SpriteEdit();
    final sprite = SpriteDef(id: 'demo', frames: [const Rect.fromLTWH(0, 0, 16, 16)], output: 16);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SpriteEditorCard(
      sprite: sprite, edit: edit, sheet: image, diagnostics: const [SpriteFrameDiagnostics(pixels: 256, visible: 256, transparent: 0, partial: 0, edges: 0, bounds: null)], expanded: true,
      onChanged: () {}, onReset: () {},
    )))));
    await tester.ensureVisible(find.byKey(const ValueKey('sprite-rotate-right-demo')));
    await tester.tap(find.byKey(const ValueKey('sprite-rotate-right-demo')));
    expect(edit.rotationQuarterTurns, 1);
    await tester.tap(find.byKey(const ValueKey('sprite-rotate-left-demo')));
    expect(edit.rotationQuarterTurns, 0);
    await tester.tap(find.byKey(const ValueKey('sprite-flip-horizontal-demo')));
    expect(edit.flipHorizontal, isTrue);
    await tester.tap(find.byKey(const ValueKey('sprite-flip-vertical-demo')));
    expect(edit.flipVertical, isTrue);
  });
}

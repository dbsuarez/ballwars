import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_edit.dart';
import 'package:ballwars/features/sprites/presentation/sprite_editor_card.dart';

void main() {
  test('duplicate frame is preserved in exported playback sequence', () {
    final sprite = SpriteDef(
      id: 'demo',
      frames: [const Rect.fromLTWH(0, 0, 8, 8), const Rect.fromLTWH(8, 0, 8, 8)],
      output: 16,
    );
    final edit = SpriteEdit()..order = [0, 0, 1];
    expect(edit.indexes(2), [0, 0, 1]);
    expect(edit.apply(sprite).frames, [sprite.frames[0], sprite.frames[0], sprite.frames[1]]);
    edit.excluded.add(0);
    expect(edit.indexes(2), [1]);
  });

  testWidgets('duplicate and remove frame copy in sprite editor', (tester) async {
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
      sprite: sprite,
      edit: edit,
      sheet: image,
      diagnostics: const [SpriteFrameDiagnostics(pixels: 256, visible: 256, transparent: 0, partial: 0, edges: 0, bounds: null)],
      expanded: true,
      onChanged: () {},
      onReset: () {},
    )))));
    final duplicate = find.byKey(const ValueKey('duplicate-frame-demo-0'));
    await tester.ensureVisible(duplicate);
    await tester.tap(duplicate);
    await tester.pump();
    expect(edit.order, [0, 0]);
    expect(find.byKey(const ValueKey('frame-demo-1')), findsOneWidget);
    final remove = find.byKey(const ValueKey('remove-frame-copy-demo-1'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();
    expect(edit.order, [0]);
  });
}

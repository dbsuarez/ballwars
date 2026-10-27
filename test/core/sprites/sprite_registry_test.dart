import 'dart:convert';
import 'dart:ui' as ui;

import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves in-memory assets.
class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, Uint8List> files = {};

  void putString(String path, String text) =>
      files[path] = Uint8List.fromList(utf8.encode(text));

  @override
  Future<ByteData> load(String key) async {
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(bytes);
  }
}

/// A sheet of [frames] squares side by side, each [cell] px wide.
Future<ui.Image> makeSheet(int frames, {int cell = 16}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var i = 0; i < frames; i++) {
    canvas.drawRect(
      ui.Rect.fromLTWH(i * cell + 4.0, 4, cell - 8.0, cell - 8.0),
      ui.Paint()..color = ui.Color(0xFF000000 | ((i * 80 + 60) << 8)),
    );
  }
  return recorder.endRecording().toImage(frames * cell, cell);
}

Future<Uint8List> pngBytes(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

String manifest(String sheet, String id, {int frames = 2}) {
  final rects = [
    for (var i = 0; i < frames; i++) [i * 16, 0, 16, 16],
  ];
  return jsonEncode({
    'sheet': sheet,
    'sprites': {
      id: {'frames': rects, 'output': 32},
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SpriteRegistry.resetForTest);

  test('load cuts frames, wraps indexes and skips a corrupt sheet', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final bundle = FakeAssetBundle();
      bundle.putString(
        SpriteRegistry.indexPath,
        jsonEncode(['a.atlas.json', 'bad.atlas.json', 'c.atlas.json']),
      );
      bundle.files['a.png'] = await pngBytes(await makeSheet(2));
      bundle.putString('a.atlas.json', manifest('a.png', 'x'));
      bundle.files['bad.png'] = Uint8List.fromList([1, 2, 3]);
      bundle.putString('bad.atlas.json', manifest('bad.png', 'broken'));
      bundle.files['c.png'] = await pngBytes(await makeSheet(2));
      bundle.putString('c.atlas.json', manifest('c.png', 'y'));

      final first = SpriteRegistry.load(bundle: bundle);
      expect(identical(first, SpriteRegistry.load(bundle: bundle)), isTrue);
      await first;

      expect(SpriteRegistry.frameCount('x'), 2);
      expect(SpriteRegistry.frame('x', 3), same(SpriteRegistry.frame('x', 1)));
      expect(SpriteRegistry.frame('x')!.width, 32);
      expect(SpriteRegistry.frame('missing'), isNull);
      expect(SpriteRegistry.frameCount('missing'), 0);
      expect(SpriteRegistry.stepsPerFrame('missing'), 4);
      expect(SpriteRegistry.has('y'), isTrue);
      expect(SpriteRegistry.has('broken'), isFalse);
      expect(SpriteRegistry.loadProblems, hasLength(1));
      expect(SpriteRegistry.loadProblems.single, contains('bad.png'));
    });
  });

  test('missing index and malformed manifest never throw', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final bundle = FakeAssetBundle();
      await SpriteRegistry.load(bundle: bundle);
      expect(SpriteRegistry.loadProblems, hasLength(1));

      SpriteRegistry.resetForTest();
      bundle.putString(SpriteRegistry.indexPath, '["m.atlas.json"]');
      bundle.putString('m.atlas.json', '{"nope": 1}');
      await SpriteRegistry.load(bundle: bundle);
      expect(SpriteRegistry.loadProblems.single, contains('m.atlas.json'));
    });
  });

  test('duplicate ids keep the first and name both manifests', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final bundle = FakeAssetBundle();
      bundle.putString(
        SpriteRegistry.indexPath,
        jsonEncode(['a.atlas.json', 'b.atlas.json']),
      );
      bundle.files['a.png'] = await pngBytes(await makeSheet(2));
      bundle.putString('a.atlas.json', manifest('a.png', 'x', frames: 2));
      bundle.files['b.png'] = await pngBytes(await makeSheet(1));
      bundle.putString('b.atlas.json', manifest('b.png', 'x', frames: 1));
      await SpriteRegistry.load(bundle: bundle);
      expect(SpriteRegistry.frameCount('x'), 2);
      expect(SpriteRegistry.loadProblems, hasLength(1));
      expect(SpriteRegistry.loadProblems.single, contains('a.atlas.json'));
      expect(SpriteRegistry.loadProblems.single, contains('b.atlas.json'));
    });
  });

  test('atlas problems skip that manifest only', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final bundle = FakeAssetBundle();
      bundle.putString(
        SpriteRegistry.indexPath,
        jsonEncode(['a.atlas.json', 'b.atlas.json']),
      );
      bundle.files['a.png'] = await pngBytes(await makeSheet(1));
      bundle.putString('a.atlas.json', manifest('a.png', 'x', frames: 2));
      bundle.files['b.png'] = await pngBytes(await makeSheet(1));
      bundle.putString('b.atlas.json', manifest('b.png', 'ok', frames: 1));
      await SpriteRegistry.load(bundle: bundle);
      expect(SpriteRegistry.has('x'), isFalse);
      expect(SpriteRegistry.has('ok'), isTrue);
      expect(SpriteRegistry.loadProblems.single, contains('outside the sheet'));
    });
  });

  test('trim and sharedBand produce output-sized frames', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final sheet = await makeSheet(2);
      final frames = [
        [0, 0, 16, 16],
        [16, 0, 16, 16],
      ];
      final atlas = SpriteAtlas.parse({
        'sheet': 's.png',
        'sprites': {
          't': {'frames': frames, 'output': 24, 'fit': 'trim'},
          'b': {'frames': frames, 'output': 24, 'sharedBand': true},
        },
      });
      await SpriteRegistry.register(atlas, sheet, idPrefix: 'custom.q');
      expect(SpriteRegistry.frame('custom.q.t', 1)!.width, 24);
      expect(SpriteRegistry.frame('custom.q.b', 0)!.height, 24);
      expect(SpriteRegistry.frameCount('custom.q.b'), 2);
    });
  });

  test('register, replace and unregister custom sprites', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final sheet = await makeSheet(2);
      SpriteAtlas atlas(int frames) => SpriteAtlas.parse({
        'sheet': 'ignored.png',
        'sprites': {
          'flame': {
            'frames': [
              for (var i = 0; i < frames; i++) [i * 16, 0, 16, 16],
            ],
            'output': 32,
          },
        },
      });

      await SpriteRegistry.register(atlas(2), sheet, idPrefix: 'custom.abc');
      expect(SpriteRegistry.has('custom.abc.flame'), isTrue);
      expect(SpriteRegistry.frameCount('custom.abc.flame'), 2);

      await SpriteRegistry.register(atlas(1), sheet, idPrefix: 'custom.abc');
      expect(SpriteRegistry.frameCount('custom.abc.flame'), 1);
      expect(SpriteRegistry.ids.where((i) => i.startsWith('custom.abc.')), [
        'custom.abc.flame',
      ]);

      SpriteRegistry.unregister('custom.abc');
      expect(SpriteRegistry.has('custom.abc.flame'), isFalse);

      await expectLater(
        SpriteRegistry.register(atlas(1), sheet, idPrefix: 'effect'),
        throwsArgumentError,
      );
    });
  });
}

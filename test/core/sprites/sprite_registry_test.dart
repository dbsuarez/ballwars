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

  test('register rejects sprite names with dots or capitals', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final sheet = await makeSheet(2);
      for (final name in ['b.c', 'Bad', '', 'a' * 41]) {
        final atlas = SpriteAtlas.parse({
          'sheet': 's.png',
          'sprites': {
            name: {
              'frames': [
                [0, 0, 16, 16],
              ],
              'output': 24,
            },
          },
        });
        expect(
          () => SpriteRegistry.register(atlas, sheet, idPrefix: 'custom.n'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              contains(name.isEmpty ? 'sprite name' : name),
            ),
          ),
        );
      }
    });
  });

  test('fill stretches a frame into a non-square output', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final sheet = await makeSheet(2);
      final atlas = SpriteAtlas.parse({
        'sheet': 's.png',
        'sprites': {
          'rim': {
            'frames': [
              [0, 4, 32, 8],
            ],
            'output': 64,
            'outputHeight': 8,
            'fit': 'fill',
            'padding': 0,
          },
        },
      });
      await SpriteRegistry.register(atlas, sheet, idPrefix: 'custom.f');
      final img = SpriteRegistry.frame('custom.f.rim')!;
      expect((img.width, img.height), (64, 8));
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int alpha(int x, int y) => bytes.getUint8((y * 64 + x) * 4 + 3);
      // Source x 4..12 (first square) lands on 8..24 when stretched 2x.
      expect(alpha(9, 4), 255);
      expect(alpha(23, 4), 255);
      expect(alpha(4, 4), 0);
      expect(alpha(26, 4), 0);
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

  test('padding sets the inner size of the cut frame', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(
        const ui.Rect.fromLTWH(0, 0, 16, 16),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final sheet = await rec.endRecording().toImage(16, 16);
      SpriteAtlas atlas(int? pad) => SpriteAtlas.parse({
        'sheet': 's.png',
        'sprites': {
          'p': {
            'frames': [
              [0, 0, 16, 16],
            ],
            'output': 32,
            'padding': ?pad,
          },
        },
      });
      Future<int> opaqueWidth(int? pad, String prefix) async {
        await SpriteRegistry.register(atlas(pad), sheet, idPrefix: prefix);
        final img = SpriteRegistry.frame('$prefix.p')!;
        final b = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        var n = 0;
        for (var x = 0; x < 32; x++) {
          if (b.getUint8((16 * 32 + x) * 4 + 3) > 200) n++;
        }
        return n;
      }

      expect(await opaqueWidth(null, 'custom.d'), 28);
      expect(await opaqueWidth(0, 'custom.z'), 32);
      expect(await opaqueWidth(6, 'custom.s'), 20);
    });
  });

  test('sharedBand keeps a tall union inside the output', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
      c.drawRect(const ui.Rect.fromLTWH(0, 0, 10, 4), paint);
      c.drawRect(const ui.Rect.fromLTWH(10, 36, 10, 4), paint);
      final sheet = await rec.endRecording().toImage(20, 40);
      final atlas = SpriteAtlas.parse({
        'sheet': 's.png',
        'sprites': {
          'tall': {
            'frames': [
              [0, 0, 10, 4],
              [10, 36, 10, 4],
            ],
            'output': 32,
            'sharedBand': true,
          },
        },
      });
      await SpriteRegistry.register(atlas, sheet, idPrefix: 'custom.t');
      // Frame 1 sits at the top of the band, frame 2 at the bottom; both
      // must be fully visible (band 40 tall scaled into 28 px).
      for (final (i, row) in [(0, 2), (1, 29)]) {
        final img = SpriteRegistry.frame('custom.t.tall', i)!;
        final b = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        var any = false;
        for (var x = 0; x < 32; x++) {
          if (b.getUint8((row * 32 + x) * 4 + 3) > 200) any = true;
        }
        expect(any, isTrue, reason: 'frame ${i + 1} row $row');
      }
    });
  });

  test(
    'register rejects atlas problems and ids owned by someone else',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final sheet = await makeSheet(1);
        final outside = SpriteAtlas.parse({
          'sheet': 's.png',
          'sprites': {
            'x': {
              'frames': [
                [0, 0, 99, 16],
              ],
              'output': 32,
            },
          },
        });
        await expectLater(
          SpriteRegistry.register(outside, sheet, idPrefix: 'custom.a'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              contains('outside the sheet'),
            ),
          ),
        );
        expect(SpriteRegistry.has('custom.a.x'), isFalse);

        // Prefix custom.a with sprite "b.c" and prefix custom.a.b with sprite
        // "c" both produce the id custom.a.b.c.
        SpriteAtlas one(String id) => SpriteAtlas.parse({
          'sheet': 's.png',
          'sprites': {
            id: {
              'frames': [
                [0, 0, 16, 16],
              ],
              'output': 32,
            },
          },
        });
        await SpriteRegistry.register(one('b.c'), sheet, idPrefix: 'custom.a');
        await expectLater(
          SpriteRegistry.register(one('c'), sheet, idPrefix: 'custom.a.b'),
          throwsArgumentError,
        );
      });
    },
  );

  group('fit trim', () {
    /// A [w] x [h] image with an opaque red rectangle at [art].
    Future<ui.Image> artImage(ui.Rect art, {int w = 64, int h = 64}) async {
      final rec = ui.PictureRecorder();
      ui.Canvas(
        rec,
      ).drawRect(art, ui.Paint()..color = const ui.Color(0xFFFF0000));
      return rec.endRecording().toImage(w, h);
    }

    /// Bounds (left, top, right, bottom, inclusive) of pixels with alpha > 16.
    Future<List<int>?> visible(ui.Image img) async {
      final b = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var l = img.width, t = img.height, r = -1, btm = -1;
      for (var y = 0; y < img.height; y++) {
        for (var x = 0; x < img.width; x++) {
          if (b.getUint8((y * img.width + x) * 4 + 3) <= 16) continue;
          if (x < l) l = x;
          if (x > r) r = x;
          if (y < t) t = y;
          if (y > btm) btm = y;
        }
      }
      return r < 0 ? null : [l, t, r, btm];
    }

    SpriteAtlas one(Map<String, Object?> entry) => SpriteAtlas.parse({
      'sheet': 's.png',
      'sprites': {'t': entry},
    });

    test('visible art fills the box without clipping or stretching', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        // The icon fit: 16 x 32 art in a 64 px cell becomes 30 x 60 px,
        // centered in the 60 px box inside a 2 px border.
        final sheet = await artImage(const ui.Rect.fromLTWH(24, 16, 16, 32));
        await SpriteRegistry.register(
          one({
            'frames': [
              [0, 0, 64, 64],
            ],
            'output': 64,
            'padding': 2,
            'fit': 'trim',
          }),
          sheet,
          idPrefix: 'custom.i',
        );
        final img = SpriteRegistry.frame('custom.i.t')!;
        expect([img.width, img.height], [64, 64]);
        expect(await visible(img), [17, 2, 46, 61]);
      });
    });

    test('measures on the output-size cut, not the sheet', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        // A 128 px cell with art in a 32 x 64 box, cut to 32 px: the art is
        // measured on the 32 px cut (8 x 16) and fills the 28 px inner box.
        final sheet = await artImage(
          const ui.Rect.fromLTWH(48, 32, 32, 64),
          w: 128,
          h: 128,
        );
        await SpriteRegistry.register(
          one({
            'frames': [
              [0, 0, 128, 128],
            ],
            'output': 32,
            'fit': 'trim',
          }),
          sheet,
          idPrefix: 'custom.m',
        );
        expect(await visible(SpriteRegistry.frame('custom.m.t')!), [
          9,
          2,
          22,
          29,
        ]);
      });
    });

    test('a non-square output contains the art in its inner box', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final sheet = await artImage(const ui.Rect.fromLTWH(20, 28, 24, 8));
        await SpriteRegistry.register(
          one({
            'frames': [
              [0, 0, 64, 64],
            ],
            'output': 64,
            'outputHeight': 32,
            'padding': 2,
            'fit': 'trim',
          }),
          sheet,
          idPrefix: 'custom.w',
        );
        final img = SpriteRegistry.frame('custom.w.t')!;
        expect([img.width, img.height], [64, 32]);
        // 24 x 8 art scaled into 60 x 28: limited by the width, 60 x 20.
        expect(await visible(img), [2, 6, 61, 25]);
      });
    });

    test('a fully transparent frame stays the plain cut', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final sheet = await artImage(ui.Rect.zero);
        await SpriteRegistry.register(
          one({
            'frames': [
              [0, 0, 64, 64],
            ],
            'output': 48,
            'fit': 'trim',
          }),
          sheet,
          idPrefix: 'custom.e',
        );
        final img = SpriteRegistry.frame('custom.e.t')!;
        expect([img.width, img.height], [48, 48]);
        expect(await visible(img), isNull);
      });
    });

    test('trimCutPadding sets the margin of the measured cut', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final sheet = await artImage(const ui.Rect.fromLTWH(0, 0, 64, 64));
        await SpriteRegistry.register(
          one({
            'frames': [
              [0, 0, 64, 64],
            ],
            'output': 64,
            'padding': 4,
            'trimCutPadding': 2,
            'fit': 'trim',
          }),
          sheet,
          idPrefix: 'custom.c',
        );
        expect(await visible(SpriteRegistry.frame('custom.c.t')!), [
          4,
          4,
          59,
          59,
        ]);
      });
    });

    test('problems reject trim with sharedBand and a stray trimCutPadding', () {
      final frames = [
        [0, 0, 16, 16],
      ];
      final atlas = SpriteAtlas.parse({
        'sheet': 's.png',
        'sprites': {
          'band': {
            'frames': frames,
            'output': 24,
            'fit': 'trim',
            'sharedBand': true,
          },
          'stray': {'frames': frames, 'output': 24, 'trimCutPadding': 2},
          'wide': {
            'frames': frames,
            'output': 24,
            'fit': 'trim',
            'trimCutPadding': 12,
          },
        },
      });
      final problems = atlas.problems(sheetSize: const ui.Size(16, 16));
      expect(problems, hasLength(3));
      expect(problems[0], contains('trim cannot be combined with sharedBand'));
      expect(problems[1], contains('stray sets trimCutPadding'));
      expect(problems[2], contains('wide trimCutPadding 12 leaves no room'));
    });
  });

  group('registerDrawn', () {
    Future<ui.Image> drawn() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(
        const ui.Rect.fromLTWH(24, 16, 16, 32),
        ui.Paint()..color = const ui.Color(0xFFFF0000),
      );
      return rec.endRecording().toImage(64, 64);
    }

    test('fits a drawn image like a manifest frame and keeps a copy', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final image = await drawn();
        await SpriteRegistry.registerDrawn(
          'powerup.test',
          image,
          fit: SpriteFit.trim,
        );
        image.dispose(); // the caller keeps ownership of its image
        final img = SpriteRegistry.frame('powerup.test')!;
        expect(SpriteRegistry.frameCount('powerup.test'), 1);
        expect([img.width, img.height], [64, 64]);
        final b = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        int alpha(int x, int y) => b.getUint8((y * 64 + x) * 4 + 3);
        expect(alpha(17, 2), 255);
        expect(alpha(46, 61), 255);
        expect(alpha(16, 30), 0);
        expect(alpha(47, 30), 0);
        expect(alpha(30, 1), 0);
        expect(alpha(30, 62), 0);
      });
    });

    test('rejects custom ids, ids in use and bad sizes', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final image = await drawn();
        await expectLater(
          SpriteRegistry.registerDrawn('custom.x', image),
          throwsArgumentError,
        );
        await SpriteRegistry.registerDrawn('drawn.a', image);
        await expectLater(
          SpriteRegistry.registerDrawn('drawn.a', image),
          throwsArgumentError,
        );
        await expectLater(
          SpriteRegistry.registerDrawn('drawn.b', image, output: 4),
          throwsArgumentError,
        );
        expect(SpriteRegistry.has('drawn.b'), isFalse);
      });
    });

    test('a manifest naming a drawn id is skipped with a problem', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final image = await drawn();
        await SpriteRegistry.registerDrawn('x', image);
        final bundle = FakeAssetBundle();
        bundle.putString(
          SpriteRegistry.indexPath,
          jsonEncode(['a.atlas.json']),
        );
        bundle.files['a.png'] = await pngBytes(await makeSheet(2));
        bundle.putString('a.atlas.json', manifest('a.png', 'x'));
        await SpriteRegistry.load(bundle: bundle);
        expect(SpriteRegistry.frame('x')!.width, 64);
        expect(SpriteRegistry.loadProblems.single, contains('drawn in code'));
      });
    });

    test('resetForTest meanwhile discards the drawn sprite', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final image = await drawn();
        final pending = SpriteRegistry.registerDrawn('drawn.r', image);
        SpriteRegistry.resetForTest();
        await pending;
        expect(SpriteRegistry.has('drawn.r'), isFalse);
      });
    });
  });

  test('resetForTest during a load discards the stale work', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final bundle = FakeAssetBundle();
      bundle.putString(SpriteRegistry.indexPath, jsonEncode(['a.atlas.json']));
      bundle.files['a.png'] = await pngBytes(await makeSheet(2));
      bundle.putString('a.atlas.json', manifest('a.png', 'x'));
      final pending = SpriteRegistry.load(bundle: bundle);
      SpriteRegistry.resetForTest();
      await pending;
      expect(SpriteRegistry.has('x'), isFalse);
      expect(SpriteRegistry.loadProblems, isEmpty);
    });
  });

  group('playback helpers', () {
    Future<void> registerFour({int steps = 3}) async {
      final sheet = await makeSheet(4);
      await SpriteRegistry.register(
        SpriteAtlas.parse({
          'sheet': 'ignored.png',
          'sprites': {
            'loop': {
              'frames': [
                for (var i = 0; i < 4; i++) [i * 16, 0, 16, 16],
              ],
              'output': 32,
              'stepsPerFrame': steps,
            },
          },
        }),
        sheet,
        idPrefix: 'custom.play',
      );
    }

    test('frameAt holds each frame stepsPerFrame steps and wraps', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        await registerFour();
        const id = 'custom.play.loop';
        for (var step = 0; step < 40; step++) {
          for (var offset = 0; offset < 4; offset++) {
            expect(
              SpriteRegistry.frameAt(id, step, offset: offset),
              same(SpriteRegistry.frame(id, (step ~/ 3 + offset) % 4)),
              reason: 'step $step offset $offset',
            );
          }
          // Per-call overrides: another rate, or fewer frames.
          expect(
            SpriteRegistry.frameAt(id, step, stepsPerFrame: 4),
            same(SpriteRegistry.frame(id, (step ~/ 4) % 4)),
          );
          expect(
            SpriteRegistry.frameAt(id, step, stepsPerFrame: 1, frameCount: 2),
            same(SpriteRegistry.frame(id, step % 2)),
          );
        }
        expect(SpriteRegistry.frameAt('missing', 3), isNull);
        // Overrides must be above 0 and frameCount at most the real count.
        expect(
          () => SpriteRegistry.frameAt(id, 1, stepsPerFrame: 0),
          throwsAssertionError,
        );
        expect(
          () => SpriteRegistry.frameAt(id, 1, frameCount: 0),
          throwsAssertionError,
        );
        expect(
          () => SpriteRegistry.frameAt(id, 1, frameCount: 5),
          throwsAssertionError,
        );
        expect(SpriteRegistry.frameAt(id, 1, frameCount: 4), isNotNull);
      });
    });

    test('frameAtProgress spreads the frames over 0..1 and clamps', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        await registerFour();
        const id = 'custom.play.loop';
        final cases = <double, int>{
          -0.5: 0,
          0.0: 0,
          0.24: 0,
          0.25: 1,
          0.6: 2,
          0.99: 3,
          1.0: 3,
          2.0: 3,
        };
        cases.forEach((t, index) {
          expect(
            SpriteRegistry.frameAtProgress(id, t),
            same(SpriteRegistry.frame(id, index)),
            reason: 't $t',
          );
        });
        expect(SpriteRegistry.frameAtProgress('missing', 0.5), isNull);
      });
    });
  });

  group('anchor', () {
    test('comes from the manifest, center by default', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final sheet = await makeSheet(2);
        await SpriteRegistry.register(
          SpriteAtlas.parse({
            'sheet': 'ignored.png',
            'sprites': {
              'low': {
                'frames': [
                  [0, 0, 16, 16],
                  [16, 0, 16, 16],
                ],
                'output': 32,
                'anchor': [0.25, 1],
              },
              'mid': {
                'frames': [
                  [0, 0, 16, 16],
                ],
                'output': 32,
              },
            },
          }),
          sheet,
          idPrefix: 'custom.anc',
        );
        expect(SpriteRegistry.anchor('custom.anc.low'), const Offset(0.25, 1));
        expect(SpriteRegistry.anchor('custom.anc.mid'), SpriteRegistry.center);
        expect(SpriteRegistry.anchor('missing'), SpriteRegistry.center);
        SpriteRegistry.unregister('custom.anc');
        expect(SpriteRegistry.anchor('custom.anc.low'), SpriteRegistry.center);
      });
    });

    test('registerDrawn takes an anchor and validates it', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final image = await makeSheet(1, cell: 32);
        await SpriteRegistry.registerDrawn('effect.a', image);
        expect(SpriteRegistry.anchor('effect.a'), SpriteRegistry.center);
        await SpriteRegistry.registerDrawn(
          'effect.b',
          image,
          anchor: const Offset(0, 0.5),
        );
        expect(SpriteRegistry.anchor('effect.b'), const Offset(0, 0.5));
        await expectLater(
          SpriteRegistry.registerDrawn(
            'effect.c',
            image,
            anchor: const Offset(1.2, 0.5),
          ),
          throwsArgumentError,
        );
        expect(SpriteRegistry.has('effect.c'), isFalse);
        SpriteRegistry.resetForTest();
        expect(SpriteRegistry.anchor('effect.b'), SpriteRegistry.center);
      });
    });

    test('placeRect puts the anchor point on the target', () {
      const target = Offset(100, 50);
      expect(
        SpriteRegistry.placeRect(target, 40, 20, SpriteRegistry.center),
        Rect.fromCenter(center: target, width: 40, height: 20),
      );
      expect(
        SpriteRegistry.placeRect(target, 40, 20, Offset.zero),
        const Rect.fromLTWH(100, 50, 40, 20),
      );
      expect(
        SpriteRegistry.placeRect(target, 40, 20, const Offset(0.5, 1)),
        const Rect.fromLTWH(80, 30, 40, 20),
      );
      expect(
        SpriteRegistry.placeRect(target, 40, 20, const Offset(0.25, 0.75)),
        const Rect.fromLTWH(90, 35, 40, 20),
      );
    });
  });

  group('sheetSize', () {
    String sized(String sheet, List<int> size) => jsonEncode({
      'sheet': sheet,
      'sheetSize': size,
      'sprites': {
        'x.$sheet': {
          'frames': [
            [0, 0, 16, 16],
          ],
          'output': 32,
        },
      },
    });

    test('load skips a manifest whose sheet has another size', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final bundle = FakeAssetBundle();
        bundle.putString(
          SpriteRegistry.indexPath,
          jsonEncode(['ok.atlas.json', 'bad.atlas.json']),
        );
        // makeSheet(2) is 32 x 16.
        bundle.files['ok.png'] = await pngBytes(await makeSheet(2));
        bundle.putString('ok.atlas.json', sized('ok.png', [32, 16]));
        bundle.files['bad.png'] = await pngBytes(await makeSheet(2));
        bundle.putString('bad.atlas.json', sized('bad.png', [32, 17]));

        await SpriteRegistry.load(bundle: bundle);
        expect(SpriteRegistry.has('x.ok.png'), isTrue);
        expect(SpriteRegistry.has('x.bad.png'), isFalse);
        expect(SpriteRegistry.loadProblems, hasLength(1));
        expect(
          SpriteRegistry.loadProblems.single,
          allOf(
            contains('bad.atlas.json'),
            contains('bad.png is 32x16, the manifest expects 32x17'),
          ),
        );
      });
    });

    test('register checks it when given', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final sheet = await makeSheet(2);
        SpriteAtlas atlas(List<int> size) => SpriteAtlas.parse({
          'sheet': 'up.png',
          'sheetSize': size,
          'sprites': {
            'a': {
              'frames': [
                [0, 0, 16, 16],
              ],
              'output': 32,
            },
          },
        });
        await expectLater(
          SpriteRegistry.register(atlas([64, 16]), sheet, idPrefix: 'custom.s'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('up.png is 32x16, the manifest expects 64x16'),
            ),
          ),
        );
        expect(SpriteRegistry.has('custom.s.a'), isFalse);
        await SpriteRegistry.register(
          atlas([32, 16]),
          sheet,
          idPrefix: 'custom.s',
        );
        expect(SpriteRegistry.has('custom.s.a'), isTrue);
      });
    });
  });
}

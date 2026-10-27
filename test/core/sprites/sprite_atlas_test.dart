import 'dart:convert';
import 'dart:ui';

import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

const _example = '''
{
  "sheet": "assets/sprites/effects-animated.png",
  "sprites": {
    "effect.explosion": {
      "frames": [[8, 218, 346, 196], [370, 218, 346, 196], [732, 218, 346, 196], [1094, 218, 346, 196]],
      "anchor": [0.5, 0.5],
      "output": 96,
      "fit": "contain",
      "stepsPerFrame": 4,
      "sharedBand": true
    }
  }
}
''';

SpriteAtlas _parse(String s) => SpriteAtlas.parse(jsonDecode(s));

void main() {
  test('parses the documented example', () {
    final atlas = _parse(_example);
    expect(atlas.sheet, 'assets/sprites/effects-animated.png');
    final def = atlas.sprites['effect.explosion']!;
    expect(def.id, 'effect.explosion');
    expect(def.frames.length, 4);
    expect(def.frames[1], const Rect.fromLTWH(370, 218, 346, 196));
    expect(def.anchor, const Offset(0.5, 0.5));
    expect(def.output, 96);
    expect(def.fit, SpriteFit.contain);
    expect(def.sharedBand, isTrue);
    expect(def.stepsPerFrame, 4);
    expect(def.bleedOk, isFalse);
    expect(atlas.problems(sheetSize: const Size(1448, 1086)), isEmpty);
  });

  test('rejects frames outside the sheet', () {
    final atlas = _parse(_example);
    final p = atlas.problems(sheetSize: const Size(1000, 1086));
    expect(p, hasLength(2));
    expect(p.first, contains('effect.explosion'));
    expect(p.first, contains('frame 3'));
    final q = atlas.problems(sheetSize: const Size(1090, 1086));
    expect(q.single, contains('effect.explosion frame 4'));
    expect(q.single, contains('outside the sheet (1090x1086)'));
  });

  test('reports frame 2 when only the second frame is outside', () {
    final atlas = _parse(
      '''
{"sheet":"s.png","sprites":{"effect.explosion":{"frames":[[0,0,10,10],[95,0,10,10]],"output":8}}}''',
    );
    final p = atlas.problems(sheetSize: const Size(100, 100));
    expect(p.single, 'effect.explosion frame 2 is outside the sheet (100x100)');
  });

  test('rejects bleedOk without a note', () {
    final bad = _parse(
      '''
{"sheet":"s.png","sprites":{"a.b":{"frames":[[0,0,10,10]],"output":8,"bleedOk":true}}}''',
    );
    final p = bad.problems(sheetSize: const Size(100, 100));
    expect(p.single, contains('a.b'));
    expect(p.single, contains('bleedNote'));
    final good = _parse(
      '''
{"sheet":"s.png","sprites":{"a.b":{"frames":[[0,0,10,10]],"output":8,"bleedOk":true,"bleedNote":"neighbour touches"}}}''',
    );
    expect(good.sprites['a.b']!.bleedNote, 'neighbour touches');
    expect(good.problems(sheetSize: const Size(100, 100)), isEmpty);
  });

  test('reports empty frame lists and overlapping frames', () {
    final empty = _parse(
      '{"sheet":"s.png","sprites":{"a.b":{"frames":[],"output":8}}}',
    );
    expect(
      empty.problems(sheetSize: const Size(100, 100)).single,
      contains('a.b has no frames'),
    );
    final overlap = _parse(
      '''
{"sheet":"s.png","sprites":{"a.b":{"frames":[[0,0,10,10],[5,5,10,10]],"output":8}}}''',
    );
    final p = overlap.problems(sheetSize: const Size(100, 100));
    expect(p.single, contains('a.b'));
    expect(p.single, contains('frames 1 and 2'));
    expect(p.single, contains('overlap'));
  });

  test('defaults stepsPerFrame to 4 and fit to contain', () {
    final atlas = _parse('''
{"sheet":"s.png","sprites":{"a.b":{"frames":[[0,0,10,10]],"output":8}}}''');
    final d = atlas.sprites['a.b']!;
    expect(d.stepsPerFrame, 4);
    expect(d.fit, SpriteFit.contain);
    expect(d.sharedBand, isFalse);
    expect(d.bleedOk, isFalse);
    expect(d.anchor, const Offset(0.5, 0.5));
    final trim = _parse(
      '''
{"sheet":"s.png","sprites":{"a.b":{"frames":[[0,0,10,10]],"output":8,"fit":"trim"}}}''',
    );
    expect(trim.sprites['a.b']!.fit, SpriteFit.trim);
  });

  test('fill fit and a non-square output (outputHeight)', () {
    final atlas = _parse(
      '''
{"sheet":"s.png","sprites":{"rim":{"frames":[[0,0,40,10]],"output":32,"outputHeight":8,"fit":"fill"}}}''',
    );
    final d = atlas.sprites['rim']!;
    expect(d.fit, SpriteFit.fill);
    expect(d.output, 32);
    expect(d.height, 8);
    expect(atlas.problems(sheetSize: const Size(40, 10)), isEmpty);
    expect(
      _parse(
        '''
{"sheet":"s.png","sprites":{"a":{"frames":[[0,0,4,4]],"output":8}}}''',
      ).sprites['a']!.height,
      8,
    );
    expect(
      () => _parse(
        '''
{"sheet":"s.png","sprites":{"a":{"frames":[[0,0,4,4]],"output":8,"outputHeight":0}}}''',
      ),
      throwsFormatException,
    );
    final tight = _parse(
      '''
{"sheet":"s.png","sprites":{"a":{"frames":[[0,0,4,4]],"output":32,"outputHeight":4,"padding":2,"sharedBand":true}}}''',
    );
    final p = tight.problems(sheetSize: const Size(10, 10));
    expect(p, hasLength(2));
    expect(p.first, contains('padding 2 leaves no room'));
    expect(p.last, contains('sharedBand needs a square output'));
  });

  test('fill combined with sharedBand is a problem', () {
    final atlas = _parse(
      '''
{"sheet":"s.png","sprites":{"rim":{"frames":[[0,0,10,10]],"output":8,"fit":"fill","sharedBand":true}}}''',
    );
    expect(atlas.problems(sheetSize: const Size(10, 10)), [
      'rim fill cannot be combined with sharedBand',
    ]);
  });

  test('malformed rect throws FormatException mentioning the id', () {
    expect(
      () => _parse(
        '''
{"sheet":"s.png","sprites":{"effect.explosion":{"frames":[[0,0,10]],"output":8}}}''',
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('effect.explosion'),
        ),
      ),
    );
  });

  test('other malformed input throws FormatException', () {
    expect(() => SpriteAtlas.parse('nope'), throwsFormatException);
    expect(() => SpriteAtlas.parse({'sprites': {}}), throwsFormatException);
    expect(
      () => _parse(
        '{"sheet":"s.png","sprites":{"a.b":{"frames":[[0,0,1,1]],"output":8,"fit":"zoom"}}}',
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('a.b'),
        ),
      ),
    );
    expect(
      () =>
          _parse('{"sheet":"s.png","sprites":{"a.b":{"frames":[[0,0,1,1]]}}}'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('a.b'),
        ),
      ),
    );
  });

  group('padding', () {
    Map<String, dynamic> withPadding(Object? p) => {
      'sheet': 's.png',
      'sprites': {
        'a': {
          'frames': [
            [0, 0, 8, 8],
          ],
          'output': 16,
          'padding': ?p,
        },
      },
    };

    test('defaults to 2 and reads an explicit value', () {
      expect(SpriteAtlas.parse(withPadding(null)).sprites['a']!.padding, 2);
      expect(SpriteAtlas.parse(withPadding(5)).sprites['a']!.padding, 5);
    });

    test('rejects bad types and reports no room', () {
      for (final bad in [-1, 'x', 1.5]) {
        expect(
          () => SpriteAtlas.parse(withPadding(bad)),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Sprite a'),
            ),
          ),
        );
      }
      final atlas = SpriteAtlas.parse(withPadding(8));
      expect(
        atlas.problems(sheetSize: const Size(8, 8)),
        contains(contains('padding 8')),
      );
    });
  });
}

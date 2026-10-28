import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/core/sprites/sprite_replacement.dart';
import 'package:flutter_test/flutter_test.dart';

SpriteAtlas sheet(String name, {int columns = 1}) => SpriteImport.grid(
  sheet: 'a.png',
  width: 64,
  height: 64,
  columns: columns,
  animation: columns == 1,
  spriteName: name,
);
void main() {
  test('single renamed icon preserves old sprite ID automatically', () {
    final old = sheet('shadow-clone'), next = sheet('new-picture');
    final mapped = SpriteReplacement.apply(
      next,
      SpriteReplacement.defaults(old, next),
    );
    expect(mapped.sprites.keys, ['shadow-clone']);
    expect(mapped.sprites.values.single.id, 'shadow-clone');
    expect(
      mapped.sprites.values.single.frames,
      next.sprites.values.single.frames,
    );
  });
  test(
    'sheet mapping preserves old names, adds new names, and explicitly removes others',
    () {
      final next = sheet('new', columns: 4);
      final mapped = SpriteReplacement.apply(next, {
        'old-attack': 'new-2',
        'old-idle': 'new-1',
        'deleted': null,
      });
      expect(mapped.sprites.keys, ['old-attack', 'old-idle', 'new-3', 'new-4']);
      expect(
        mapped.sprites['old-attack']!.frames,
        next.sprites['new-2']!.frames,
      );
    },
  );
  test('duplicate, missing and conflicting mappings fail visibly', () {
    final next = sheet('sprite', columns: 2);
    expect(
      () => SpriteReplacement.apply(next, {'a': 'sprite-1', 'b': 'sprite-1'}),
      throwsFormatException,
    );
    expect(
      () => SpriteReplacement.apply(next, {'a': 'missing'}),
      throwsFormatException,
    );
    expect(
      () => SpriteReplacement.apply(next, {'sprite-2': 'sprite-1'}),
      throwsFormatException,
    );
    expect(
      () => SpriteReplacement.apply(next, {'sprite-1': null}),
      throwsFormatException,
    );
  });
}

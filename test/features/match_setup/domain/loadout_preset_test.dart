import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/match_setup/data/loadout_preset_store.dart';
import 'package:ballwars/features/match_setup/domain/loadout_preset.dart';

void main() {
  test('built-in pools are distinct and contain no automatic traps', () {
    final military = LoadoutPreset.builtIns.first;
    final unique = LoadoutPreset.builtIns[1];
    expect(military.kinds, contains(PowerUpKind.rocketLauncher));
    expect(unique.kinds, contains(PowerUpKind.boomerang));
    expect(unique.kinds.intersection(military.kinds), isEmpty);
    for (final preset in LoadoutPreset.builtIns) {
      expect(preset.kinds, isNotEmpty);
      expect(preset.kinds.any((k) => k.isTrap), isFalse);
    }
  });

  test(
    'named presets survive a new store and retain independent custom IDs',
    () async {
      final offline = MemoryOfflineStore();
      final preset = LoadoutPreset(
        id: 'one',
        name: 'My pool',
        kinds: {PowerUpKind.boomerang, PowerUpKind.mine},
        customIds: {'custom.boom-merang', 'custom.kutsilyo'},
      );
      await LoadoutPresetStore(store: offline).write([preset]);
      final saved = (await LoadoutPresetStore(store: offline).read()).single;
      expect(saved.name, 'My pool');
      expect(saved.kinds, {PowerUpKind.boomerang});
      expect(saved.customIds, {'custom.boom-merang', 'custom.kutsilyo'});
      expect(saved.renamed('Changed').id, saved.id);
      expect(saved.renamed('Changed').customIds, saved.customIds);
    },
  );

  test(
    'malformed storage is reported rather than overwritten with an empty list',
    () async {
      final offline = MemoryOfflineStore();
      await offline.write(LoadoutPresetStore.key, utf8.encode('invalid'));
      await expectLater(
        LoadoutPresetStore(store: offline).read(),
        throwsFormatException,
      );
      expect(
        utf8.decode((await offline.read(LoadoutPresetStore.key))!),
        'invalid',
      );
    },
  );
}

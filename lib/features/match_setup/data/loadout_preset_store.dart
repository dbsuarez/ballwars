import 'dart:convert';
import '../../../core/offline/offline_store.dart';
import '../domain/loadout_preset.dart';

/// Device-local named presets. Errors propagate so the UI never claims a failed save.
class LoadoutPresetStore {
  LoadoutPresetStore({OfflineStore? store})
    : _store = store ?? OfflineStore.instance;
  final OfflineStore _store;
  static const key = 'pref:loadout-presets-v1';

  Future<List<LoadoutPreset>> read() async {
    final bytes = await _store.read(key);
    if (bytes == null) return [];
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unknown preset version');
    }
    return (data['presets'] as List)
        .map(
          (json) =>
              LoadoutPreset.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<void> write(List<LoadoutPreset> presets) => _store.write(
    key,
    utf8.encode(
      jsonEncode({
        'version': 1,
        'presets': presets.map((preset) => preset.toJson()).toList(),
      }),
    ),
  );
}

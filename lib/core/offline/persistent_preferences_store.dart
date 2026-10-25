import 'package:flutter/foundation.dart';

import 'offline_store.dart';

/// Separates small preferences and settings from replaceable resource caches.
class PersistentPreferencesStore implements OfflineStore {
  PersistentPreferencesStore({
    required this.resources,
    required this.readPersistent,
    required this.writePersistent,
  });

  final OfflineStore resources;
  final Future<Uint8List?> Function(String) readPersistent;
  final Future<void> Function(String, Uint8List) writePersistent;

  bool _persistent(String key) => key.startsWith('pref:') || key == 'settings';

  @override
  Future<Uint8List?> read(String key) async {
    if (!_persistent(key)) return resources.read(key);
    try {
      final saved = await readPersistent(key);
      if (saved != null) return saved;
    } catch (_) {
      // Fall back when browser storage is blocked.
    }
    final legacy = await resources.read(key);
    if (legacy != null) {
      try {
        await writePersistent(key, legacy);
      } catch (_) {}
    }
    return legacy;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (!_persistent(key)) return resources.write(key, bytes);
    try {
      await writePersistent(key, bytes);
    } catch (_) {
      await resources.write(key, bytes);
    }
  }

  @override
  Future<Set<String>> missing(Iterable<String> keys) async {
    final result = await resources.missing(keys.where((key) => !_persistent(key)));
    for (final key in keys.where(_persistent)) {
      if (await read(key) == null) result.add(key);
    }
    return result;
  }
}

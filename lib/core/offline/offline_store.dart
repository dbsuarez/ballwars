import 'package:flutter/foundation.dart';
import 'offline_store_stub.dart'
    if (dart.library.io) 'offline_store_io.dart'
    if (dart.library.js_interop) 'offline_store_web.dart';

/// Keeps downloaded resources (pack catalog, ball images, groups, settings)
/// on the device so the app works offline: files in the app's own storage on
/// Android, the browser's Cache Storage on web. Keys are any strings (image
/// URLs, or names like `packs.json`).
abstract class OfflineStore {
  /// The store the app uses. In-memory until `main` swaps in the device one,
  /// so tests never touch real storage.
  static OfflineStore instance = MemoryOfflineStore();

  /// The device store for this platform (in-memory where there is none).
  static OfflineStore platform() => createPlatformStore() ?? MemoryOfflineStore();

  Future<Uint8List?> read(String key);

  Future<void> write(String key, Uint8List bytes);

  /// The [keys] that are not stored yet.
  Future<Set<String>> missing(Iterable<String> keys);
}

class MemoryOfflineStore implements OfflineStore {
  final Map<String, Uint8List> _data = {};

  @override
  Future<Uint8List?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, Uint8List bytes) async => _data[key] = bytes;

  @override
  Future<Set<String>> missing(Iterable<String> keys) async => {
        for (final k in keys)
          if (!_data.containsKey(k)) k,
      };
}

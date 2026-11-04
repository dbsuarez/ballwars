import 'dart:convert';
import 'offline_store.dart';

/// Small per-device choices (Match Setup's rounds and speed, ...) kept in
/// [OfflineStore] so they are remembered across restarts. Reads fall back to
/// null and failed writes are ignored: a lost choice just means the default.
class DevicePrefs {
  DevicePrefs._();

  static Future<String?> read(String key) async {
    try {
      return await readRequired(key);
    } catch (_) {
      return null;
    }
  }

  /// Durable user data must not mistake an unreadable record for an empty one.
  static Future<String?> readRequired(String key) async {
    await _writes;
    final bytes = await OfflineStore.instance.read('pref:$key');
    return bytes == null ? null : utf8.decode(bytes);
  }

  // A successful queue tail keeps failed durable writes from poisoning retries.
  static Future<void>? _writes;

  static Future<void> write(String key, Object value) async {
    try {
      await writeRequired(key, value);
    } catch (_) {}
  }

  /// Persist and read back before confirming a durable user-data save.
  static Future<void> writeRequired(String key, Object value) {
    final store = OfflineStore.instance;
    final text = '$value';
    final bytes = utf8.encode(text);
    final task = (_writes ?? Future<void>.value()).then((_) async {
      await store.write('pref:$key', bytes);
      final saved = await store.read('pref:$key');
      if (saved == null || utf8.decode(saved) != text) {
        throw StateError(
          'Device storage did not confirm the save. Free some space and retry.',
        );
      }
    });
    late final Future<void> tail;
    tail = task
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_writes, tail)) _writes = null;
        });
    _writes = tail;
    return task.whenComplete(() => tail);
  }
}

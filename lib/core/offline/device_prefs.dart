import 'dart:convert';
import 'offline_store.dart';

/// Small per-device choices (Match Setup's rounds and speed, ...) kept in
/// [OfflineStore] so they are remembered across restarts. Reads fall back to
/// null and failed writes are ignored: a lost choice just means the default.
class DevicePrefs {
  DevicePrefs._();

  static Future<String?> read(String key) async {
    try {
      final pending = _writes;
      if (pending != null) await pending;
      final bytes = await OfflineStore.instance.read('pref:$key');
      return bytes == null ? null : utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  // Auth refresh and explicit sign-in may save at the same time. Serialize
  // writes so Android's atomic file replacement cannot race on one temp file.
  static Future<void>? _writes;

  static Future<void> write(String key, Object value) {
    final store = OfflineStore.instance;
    final bytes = utf8.encode('$value');
    Future<void> save() async {
      try {
        await store.write('pref:$key', bytes);
      } catch (_) {}
    }
    final pending = _writes;
    final task = pending == null ? save() : pending.then((_) => save());
    late final Future<void> next;
    next = task.whenComplete(() {
      if (identical(_writes, next)) _writes = null;
    });
    _writes = next;
    return next;
  }
}

import 'dart:convert';
import 'offline_store.dart';

/// Small per-device choices (Match Setup's rounds and speed, ...) kept in
/// [OfflineStore] so they are remembered across restarts. Reads fall back to
/// null and failed writes are ignored: a lost choice just means the default.
class DevicePrefs {
  DevicePrefs._();

  static Future<String?> read(String key) async {
    try {
      await _writes;
      final bytes = await OfflineStore.instance.read('pref:$key');
      return bytes == null ? null : utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  // Auth refresh and explicit sign-in may save at the same time. Serialize
  // writes so Android's atomic file replacement cannot race on one temp file.
  static Future<void> _writes = Future.value();

  static Future<void> write(String key, Object value) {
    final store = OfflineStore.instance;
    final bytes = utf8.encode('$value');
    final next = _writes.then((_) async {
      try {
        await store.write('pref:$key', bytes);
      } catch (_) {}
    });
    _writes = next;
    return next;
  }
}

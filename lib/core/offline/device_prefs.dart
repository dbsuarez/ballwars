import 'dart:convert';
import 'offline_store.dart';

/// Small per-device choices (Match Setup's rounds and speed, ...) kept in
/// [OfflineStore] so they are remembered across restarts. Reads fall back to
/// null and failed writes are ignored: a lost choice just means the default.
class DevicePrefs {
  DevicePrefs._();

  static Future<String?> read(String key) async {
    try {
      final bytes = await OfflineStore.instance.read('pref:$key');
      return bytes == null ? null : utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, Object value) async {
    try {
      await OfflineStore.instance.write('pref:$key', utf8.encode('$value'));
    } catch (_) {}
  }
}

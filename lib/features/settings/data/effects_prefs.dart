import 'dart:convert';
import '../../../core/offline/offline_store.dart';

/// This device's choices about particle effects (sparks, confetti), kept in
/// [OfflineStore] so they survive restarts: whether new matches start with
/// effects on, and whether the winner card may still ask to turn them off.
class EffectsPrefs {
  EffectsPrefs._();

  static const String _effectsKey = 'pref:effects';
  static const String _askKey = 'pref:ask-effects';

  static Future<bool> finishersOn() => _read('pref:finishers', true);

  static Future<void> setFinishersOn(bool on) => _write('pref:finishers', on);

  static Future<bool> effectsOn() => _read(_effectsKey, true);

  static Future<void> setEffectsOn(bool on) => _write(_effectsKey, on);

  /// False once the player ticked "Don't ask again".
  static Future<bool> askWhenSlow() => _read(_askKey, true);

  static Future<void> setAskWhenSlow(bool ask) => _write(_askKey, ask);

  static Future<bool> _read(String key, bool fallback) async {
    try {
      final bytes = await OfflineStore.instance.read(key);
      return bytes == null ? fallback : utf8.decode(bytes) == 'true';
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> _write(String key, bool value) async {
    try {
      await OfflineStore.instance.write(key, utf8.encode('$value'));
    } catch (_) {
      // Not saved; the default applies next time.
    }
  }
}

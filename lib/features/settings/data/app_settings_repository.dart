import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/offline/device_prefs.dart';
import '../../../core/offline/offline_store.dart';
import '../domain/app_settings.dart';

/// Reads the app-wide settings (anyone) and changes them (admin only; the
/// database refuses everyone else).
abstract class AppSettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

/// The admin account: a normal email + password user listed in the
/// `admins` table. Everyone else signs in anonymously and is never admin.
abstract class AdminAuth {
  /// Whether this device is signed in as an admin.
  Future<bool> isAdmin();

  /// Signs in with email and password; throws if wrong or not an admin.
  Future<void> signIn(String email, String password);

  /// Signs out of the admin account (the device's own account stays).
  Future<void> signOut();

  String? get email;
}

class SupabaseAppSettingsRepository implements AppSettingsRepository {
  final SupabaseClient _client;

  /// Saves go through the admin's client (see [SupabaseAdminAuth.client]).
  final SupabaseClient _writer;

  // The watermark columns come with migration 003; until it has been run
  // they are missing and are neither read nor written.
  bool _hasWatermarkColumns = false;
  // Likewise the music column (migration 005).
  bool _hasMusicColumn = false;
  // And the slow-motion column (migration 006), and Home music (009).
  bool _hasSlowMotionColumn = false;
  bool _hasMenuMusicColumn = false;

  SupabaseAppSettingsRepository(this._client, {SupabaseClient? writer}) : _writer = writer ?? _client;

  @override
  Future<AppSettings> load() async {
    // Offline, the settings last loaded are used (theme, headline, ...).
    const key = 'settings';
    Map<String, dynamic>? row;
    try {
      // No retries: offline, fall back to the saved copy right away.
      row = await _client
          .from('app_settings')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .retry(enabled: false)
          .timeout(const Duration(seconds: 8));
      if (row != null) await OfflineStore.instance.write(key, utf8.encode(jsonEncode(row)));
    } catch (_) {
      final saved = await OfflineStore.instance.read(key);
      if (saved == null) rethrow;
      row = jsonDecode(utf8.decode(saved)) as Map<String, dynamic>;
    }
    if (row == null) return AppSettings.defaults;
    _hasWatermarkColumns = row.containsKey('watermark_enabled');
    _hasMusicColumn = row.containsKey('music');
    _hasSlowMotionColumn = row.containsKey('slow_motion_lines');
    _hasMenuMusicColumn = row.containsKey('menu_music');
    return AppSettings(
      headline: row['headline'] as String,
      themeId: row['theme'] as String,
      watermarkEnabled: row['watermark_enabled'] as bool? ?? true,
      watermarkText: row['watermark_text'] as String? ?? AppSettings.defaultWatermark,
      musicId: row['music'] as String? ?? AppSettings.defaultMusic,
      menuMusicId: row['menu_music'] as String? ?? AppSettings.defaultMenuMusic,
      slowMotionLines: (row['slow_motion_lines'] as num?)?.toInt() ?? AppSettings.defaultSlowMotionLines,
      slowMotionBeforeWinSeconds: (row['slow_motion_before_win'] as num?)?.toDouble(),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final updated = await _writer
        .from('app_settings')
        .update({
          'headline': settings.headline.trim(),
          'theme': settings.themeId,
          if (_hasWatermarkColumns) 'watermark_enabled': settings.watermarkEnabled,
          if (_hasWatermarkColumns) 'watermark_text': settings.watermarkText.trim(),
          if (_hasMusicColumn) 'music': settings.musicId,
          if (_hasMenuMusicColumn) 'menu_music': settings.menuMusicId,
          if (_hasSlowMotionColumn) 'slow_motion_lines': settings.slowMotionLines,
          if (_hasSlowMotionColumn) 'slow_motion_before_win': settings.slowMotionBeforeWinSeconds,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', 1)
        .select('id');
    // RLS turns a non-admin update into "0 rows", not an error.
    if (updated.isEmpty) throw StateError('Only the admin can change settings.');
  }
}

/// The admin signs in on a second, separate Supabase client. The app's main
/// client keeps this device's anonymous session, which owns its groups and
/// the groups it added, so signing in or out as admin never orphans them.
/// The admin session is kept in device storage across restarts.
class SupabaseAdminAuth implements AdminAuth {
  /// Use for admin-only work (saving settings, editing anyone's groups).
  final SupabaseClient client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.publishableKey);

  static const String _sessionKey = 'admin-session';
  Future<void>? _restored;

  SupabaseAdminAuth() {
    client.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (state.event == AuthChangeEvent.signedOut) {
        DevicePrefs.write(_sessionKey, '');
      } else if (session != null) {
        DevicePrefs.write(_sessionKey, jsonEncode(session.toJson()));
      }
    }, onError: (Object _) {});
  }

  /// Brings back the saved admin session (once).
  Future<void> _restore() => _restored ??= () async {
        final saved = await DevicePrefs.read(_sessionKey);
        if (saved == null || saved.isEmpty) return;
        try {
          await client.auth.recoverSession(saved);
        } on AuthException {
          await DevicePrefs.write(_sessionKey, ''); // Expired or revoked.
        } catch (_) {
          // Offline: keep it for next time.
        }
      }();

  @override
  String? get email => client.auth.currentUser?.email;

  @override
  Future<bool> isAdmin() async {
    await _restore();
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    try {
      return await client.rpc('is_admin') as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
    if (!await isAdmin()) {
      await client.auth.signOut();
      throw StateError('That account is not an admin.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } finally {
      await DevicePrefs.write(_sessionKey, '');
    }
  }
}

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Signs out; the device goes back to an anonymous account when needed.
  Future<void> signOut();

  String? get email;
}

class SupabaseAppSettingsRepository implements AppSettingsRepository {
  final SupabaseClient _client;

  // The watermark columns come with migration 003; until it has been run
  // they are missing and are neither read nor written.
  bool _hasWatermarkColumns = false;
  // Likewise the music column (migration 005).
  bool _hasMusicColumn = false;

  SupabaseAppSettingsRepository(this._client);

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
    return AppSettings(
      headline: row['headline'] as String,
      themeId: row['theme'] as String,
      watermarkEnabled: row['watermark_enabled'] as bool? ?? true,
      watermarkText: row['watermark_text'] as String? ?? AppSettings.defaultWatermark,
      musicId: row['music'] as String? ?? AppSettings.defaultMusic,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final updated = await _client
        .from('app_settings')
        .update({
          'headline': settings.headline.trim(),
          'theme': settings.themeId,
          if (_hasWatermarkColumns) 'watermark_enabled': settings.watermarkEnabled,
          if (_hasWatermarkColumns) 'watermark_text': settings.watermarkText.trim(),
          if (_hasMusicColumn) 'music': settings.musicId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', 1)
        .select('id');
    // RLS turns a non-admin update into "0 rows", not an error.
    if (updated.isEmpty) throw StateError('Only the admin can change settings.');
  }
}

class SupabaseAdminAuth implements AdminAuth {
  final SupabaseClient _client;

  SupabaseAdminAuth(this._client);

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    try {
      return await _client.rpc('is_admin') as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
    if (!await isAdmin()) {
      await _client.auth.signOut();
      throw StateError('That account is not an admin.');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

import '../../arena_simulation/domain/power_up_config.dart';
import '../../skills/domain/skill_library.dart';
import 'dart:convert';
import 'dart:ui';
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
  Future<void> signIn(String email, String password, {bool rememberMe = false});

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
  bool _hasPowerUpsColumn = false;
  bool _hasBallGlowColumn = false;
  bool _hasBloodColorColumn = false;
  bool _hasArenaTextColumns = false;
  bool _hasMinimumArenaScaleColumn = false;
  bool _hasSkillLibraryColumn = false;
  bool _hasArenaDecorationColumn = false;
  bool _hasEffectRenderModesColumn = false;

  SupabaseAppSettingsRepository(this._client, {SupabaseClient? writer})
    : _writer = writer ?? _client;

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
      if (row != null) {
        try {
          await OfflineStore.instance.write(key, utf8.encode(jsonEncode(row)));
        } catch (_) {
          // A cache failure must not discard freshly loaded server settings.
        }
      }
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
    _hasPowerUpsColumn = row.containsKey('power_ups');
    _hasBallGlowColumn = row.containsKey('ball_glow_enabled');
    _hasBloodColorColumn = row.containsKey('blood_color');
    _hasArenaTextColumns =
        row.containsKey('arena_title') && row.containsKey('arena_subtitle');
    _hasMinimumArenaScaleColumn = row.containsKey('minimum_arena_scale');
    _hasSkillLibraryColumn = row.containsKey('skill_library');
    _hasArenaDecorationColumn = row.containsKey('arena_decoration');
    _hasEffectRenderModesColumn =
        row.containsKey('projectile_render_mode') &&
        row.containsKey('explosion_render_mode') &&
        row.containsKey('freeze_render_mode');
    final legacyPowerUps = PowerUpConfig.fromJson(row['power_ups']);
    final skillLibrary = SkillLibrary.fromJson(row['skill_library']);
    return AppSettings(
      headline: row['headline'] as String,
      themeId: row['theme'] as String,
      watermarkEnabled: row['watermark_enabled'] as bool? ?? true,
      ballGlowEnabled: row['ball_glow_enabled'] as bool? ?? true,
      bloodColor: Color(
        (row['blood_color'] as num?)?.toInt() ??
            AppSettings.defaultBloodColor.toARGB32(),
      ),
      arenaTitle:
          row['arena_title'] as String? ?? AppSettings.defaultArenaTitle,
      arenaSubtitle:
          row['arena_subtitle'] as String? ?? AppSettings.defaultArenaSubtitle,
      minimumArenaScale:
          (row['minimum_arena_scale'] as num?)?.toDouble() ??
          AppSettings.defaultMinimumArenaScale,
      arenaDecoration: ArenaDecoration.values.firstWhere(
        (value) => value.name == row!['arena_decoration'],
        orElse: () => ArenaDecoration.defaultArena,
      ),
      projectileRenderMode: _renderMode(row['projectile_render_mode']),
      explosionRenderMode: _renderMode(row['explosion_render_mode']),
      freezeRenderMode: _renderMode(row['freeze_render_mode']),
      watermarkText:
          row['watermark_text'] as String? ?? AppSettings.defaultWatermark,
      musicId: row['music'] as String? ?? AppSettings.defaultMusic,
      menuMusicId: row['menu_music'] as String? ?? AppSettings.defaultMenuMusic,
      slowMotionLines:
          (row['slow_motion_lines'] as num?)?.toInt() ??
          AppSettings.defaultSlowMotionLines,
      slowMotionBeforeWinSeconds: (row['slow_motion_before_win'] as num?)
          ?.toDouble(),
      powerUps: skillLibrary.applyTo(legacyPowerUps),
      skillLibrary: skillLibrary,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (!_hasPowerUpsColumn && !settings.powerUps.isDefault) {
      throw StateError(
        'Power-up settings could not be saved: the power_ups '
        'column was not loaded. Reload settings; if it is missing, apply migration 011.',
      );
    }
    if (!_hasArenaTextColumns &&
        (settings.arenaTitle != AppSettings.defaultArenaTitle ||
            settings.arenaSubtitle != AppSettings.defaultArenaSubtitle)) {
      throw StateError(
        'Arena branding was not saved: reload settings. If arena_title or arena_subtitle is missing, apply migration 014_arena_text.sql.',
      );
    }
    if (!_hasSkillLibraryColumn && !settings.skillLibrary.isDefault) {
      throw StateError(
        'Skill Management could not be saved: apply migration 016_skill_library.sql and reload settings.',
      );
    }
    if (!_hasArenaDecorationColumn &&
        settings.arenaDecoration != ArenaDecoration.defaultArena) {
      throw StateError(
        'Arena decoration was not saved: apply migration 017_arena_decoration.sql and reload settings.',
      );
    }
    if (!_hasEffectRenderModesColumn &&
        (settings.projectileRenderMode != EffectRenderMode.sprite ||
            settings.explosionRenderMode != EffectRenderMode.sprite ||
            settings.freezeRenderMode != EffectRenderMode.sprite)) {
      throw StateError(
        'Effect rendering was not saved: apply migration 018_effect_render_modes.sql and reload settings.',
      );
    }
    final updated = await _writer
        .from('app_settings')
        .update({
          'headline': settings.headline.trim(),
          'theme': settings.themeId,
          if (_hasWatermarkColumns)
            'watermark_enabled': settings.watermarkEnabled,
          if (_hasWatermarkColumns)
            'watermark_text': settings.watermarkText.trim(),
          if (_hasMusicColumn) 'music': settings.musicId,
          if (_hasMenuMusicColumn) 'menu_music': settings.menuMusicId,
          if (_hasSlowMotionColumn)
            'slow_motion_lines': settings.slowMotionLines,
          if (_hasSlowMotionColumn)
            'slow_motion_before_win': settings.slowMotionBeforeWinSeconds,
          if (_hasPowerUpsColumn) 'power_ups': settings.powerUps.toJson(),
          if (_hasSkillLibraryColumn)
            'skill_library': settings.skillLibrary.toJson(),
          if (_hasBallGlowColumn) 'ball_glow_enabled': settings.ballGlowEnabled,
          if (_hasBloodColorColumn)
            'blood_color': settings.bloodColor.toARGB32(),
          if (_hasArenaTextColumns) 'arena_title': settings.arenaTitle.trim(),
          if (_hasArenaTextColumns)
            'arena_subtitle': settings.arenaSubtitle.trim(),
          if (_hasMinimumArenaScaleColumn)
            'minimum_arena_scale': settings.minimumArenaScale,
          if (_hasArenaDecorationColumn)
            'arena_decoration': settings.arenaDecoration.name,
          if (_hasEffectRenderModesColumn)
            'projectile_render_mode': settings.projectileRenderMode.name,
          if (_hasEffectRenderModesColumn)
            'explosion_render_mode': settings.explosionRenderMode.name,
          if (_hasEffectRenderModesColumn)
            'freeze_render_mode': settings.freezeRenderMode.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', 1)
        .select();
    // RLS turns a non-admin update into "0 rows", not an error.
    if (updated.isEmpty) {
      throw StateError('Only the admin can change settings.');
    }
    if (_hasArenaTextColumns &&
        (updated.first['arena_title'] != settings.arenaTitle.trim() ||
            updated.first['arena_subtitle'] != settings.arenaSubtitle.trim())) {
      throw StateError(
        'The server did not confirm the arena branding. Reload settings before saving again.',
      );
    }
    if (_hasSkillLibraryColumn) {
      final confirmed = SkillLibrary.fromJson(updated.first['skill_library']);
      if (jsonEncode(confirmed.toJson()) !=
          jsonEncode(settings.skillLibrary.toJson())) {
        throw StateError(
          'The server did not confirm the Skill Library. Reload settings before saving again.',
        );
      }
    }
    try {
      await OfflineStore.instance.write(
        'settings',
        utf8.encode(jsonEncode(updated.first)),
      );
    } catch (_) {
      // The server save succeeded; report cache failure separately on next load.
    }
  }

  static EffectRenderMode _renderMode(Object? value) =>
      EffectRenderMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => EffectRenderMode.sprite,
      );
}

/// The admin signs in on a second, separate Supabase client. The app's main
/// client keeps this device's anonymous session, which owns its groups and
/// the groups it added, so signing in or out as admin never orphans them.
/// The admin session is kept across restarts only with "Remember me".
class SupabaseAdminAuth implements AdminAuth {
  /// Use for admin-only work (saving settings, editing anyone's groups).
  final SupabaseClient client = SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.publishableKey,
  );

  static const String _sessionKey = 'admin-session';
  static const String _rememberKey = 'admin-remember-me';
  late final Future<void> _restored;
  bool _rememberSession = false;

  SupabaseAdminAuth() {
    _restored = _initialize();
  }

  Future<void> _initialize() async {
    // Read the durable choice before listening to auth events. A standalone
    // Supabase client can emit an initial-session event immediately; the old
    // ordering handled that while `_rememberSession` was still false and
    // replaced a valid saved session with an empty value on hard refresh.
    _rememberSession = await DevicePrefs.read(_rememberKey) == '1';
    final saved = _rememberSession ? await DevicePrefs.read(_sessionKey) : null;

    if (!_rememberSession) {
      await DevicePrefs.write(_sessionKey, '');
    } else if (saved != null && saved.isNotEmpty) {
      try {
        await client.auth.recoverSession(saved);
      } on AuthException catch (error) {
        // Retryable network/server failures must not erase a remembered
        // session. Only a definitively rejected token should clear it.
        if (const {
          '400',
          '401',
          '403',
        }.contains(error.statusCode?.toString())) {
          await DevicePrefs.write(_sessionKey, '');
        }
      } catch (_) {
        // Offline: keep it for next time.
      }
    }

    // Subscribe only after recovery. Otherwise the client's initial signed-out
    // event can clear the stored token before recoverSession gets to read it.
    client.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (state.event == AuthChangeEvent.signedOut) {
        DevicePrefs.write(_sessionKey, '');
      } else if (session != null && _rememberSession) {
        DevicePrefs.write(_sessionKey, jsonEncode(session.toJson()));
      }
    }, onError: (Object _) {});
  }

  /// Brings back the saved admin session (once).
  Future<void> _restore() => _restored;

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
  Future<void> signIn(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    // Finish startup restoration before beginning a new login. Otherwise the
    // lazy restore can recover an old token over the newly authenticated one.
    await _restore();
    _rememberSession = rememberMe;
    await DevicePrefs.write(_rememberKey, rememberMe ? '1' : '');
    try {
      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (!await isAdmin()) {
        await client.auth.signOut();
        throw StateError('That account is not an admin.');
      }
      final session = client.auth.currentSession;
      if (rememberMe && session != null) {
        final encoded = jsonEncode(session.toJson());
        await DevicePrefs.write(_sessionKey, encoded);
        if (await DevicePrefs.read(_sessionKey) != encoded) {
          throw StateError(
            'Remember me could not save this session on the device.',
          );
        }
      } else {
        await DevicePrefs.write(_sessionKey, '');
      }
    } catch (_) {
      _rememberSession = false;
      await DevicePrefs.write(_sessionKey, '');
      await DevicePrefs.write(_rememberKey, '');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } finally {
      await DevicePrefs.write(_sessionKey, '');
      await DevicePrefs.write(_rememberKey, '');
      _rememberSession = false;
    }
  }
}

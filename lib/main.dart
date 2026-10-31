import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/audio/game_audio.dart';
import 'core/config/supabase_config.dart';
import 'core/offline/offline_store.dart';
import 'features/custom_groups/data/custom_group_repository.dart';
import 'features/replay_export/data/short_link_repository.dart';
import 'features/settings/data/app_settings_repository.dart';
import 'features/sprites/data/sprite_atlas_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  // Downloads are kept on the device (app storage / browser cache) for offline play.
  OfflineStore.instance = OfflineStore.platform();
  GameAudio.instance.enabled = true;
  await GameAudio.instance.init();
  // Local setup only (no network); sign-in happens when a group is first used.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final client = Supabase.instance.client;
  // Older versions signed the admin in on this client, replacing the device's
  // anonymous account. The admin now has a session of their own (see
  // SupabaseAdminAuth), so put this client back to an anonymous one.
  final user = client.auth.currentUser;
  if (user != null && !user.isAnonymous) {
    try {
      await client.auth.signOut();
    } catch (_) {}
  }
  final admin = SupabaseAdminAuth(client);
  final deviceGroups = SupabaseCustomGroupRepository(client);
  final adminGroups = SupabaseCustomGroupRepository(admin.client);
  final groups = AccountAwareCustomGroupRepository(
    device: deviceGroups,
    account: adminGroups,
    isAccountActive: admin.isAdmin,
    adoptGroupsFrom: adminGroups.adoptGroupsFrom,
  );
  runApp(
    BallWarsApp(
      customGroups: groups,
      adminGroups: adminGroups,
      settingsRepository: SupabaseAppSettingsRepository(
        client,
        writer: admin.client,
      ),
      adminAuth: admin,
      sprites: SupabaseSpriteAtlasRepository(client, writer: admin.client),
      shortLinks: SupabaseShortLinkRepository(client),
      syncOffline: true,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'features/custom_groups/data/custom_group_repository.dart';
import 'features/replay_export/data/short_link_repository.dart';
import 'features/settings/data/app_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local setup only (no network); sign-in happens when a group is first used.
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  final client = Supabase.instance.client;
  runApp(
    BallWarsApp(
      customGroups: SupabaseCustomGroupRepository(client),
      settingsRepository: SupabaseAppSettingsRepository(client),
      adminAuth: SupabaseAdminAuth(client),
      shortLinks: SupabaseShortLinkRepository(client),
    ),
  );
}

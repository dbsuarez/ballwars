import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'features/custom_groups/data/custom_group_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local setup only (no network); sign-in happens when a group is first used.
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  runApp(BallWarsApp(customGroups: SupabaseCustomGroupRepository(Supabase.instance.client)));
}

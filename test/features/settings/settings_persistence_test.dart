import 'dart:convert';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PostgREST inspects response.request.method when handling maybeSingle GETs.
// Its JSON response is a row array; maybeSingle unwraps it inside the SDK.
void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());

  test('successful power-up save refreshes the offline settings backup', () async {
    var offline = false;
    final row = <String, dynamic>{
      'id': 1, 'headline': 'WHO WINS?', 'theme': 'midnight', 'power_ups': <String, dynamic>{},
    };
    final client = SupabaseClient('https://example.supabase.co', 'test-key',
      httpClient: MockClient((request) async {
        if (offline) return http.Response('offline', 503, request: request);
        if (request.method == 'PATCH') {
          row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode([row]), 200, request: request, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode([row]), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAppSettingsRepository(client);
    final loaded = await repository.load();
    final tuning = PowerUpConfig.defaults.withValue('dmg.pistol', 23);
    await repository.save(loaded.copyWith(powerUps: tuning));
    offline = true;
    final reopened = await SupabaseAppSettingsRepository(client).load();
    expect(reopened.powerUps, tuning);
  });

  test('missing power-up column cannot silently discard changed numbers', () async {
    var writes = 0;
    final client = SupabaseClient('https://example.supabase.co', 'test-key',
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') writes++;
        return http.Response(jsonEncode([{'id': 1, 'headline': 'WHO WINS?', 'theme': 'midnight'}]),
          200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAppSettingsRepository(client);
    final loaded = await repository.load();
    await expectLater(repository.save(loaded.copyWith(
      powerUps: PowerUpConfig.defaults.withValue('dmg.pistol', 23),
    )), throwsStateError);
    expect(writes, 0);
  });
}

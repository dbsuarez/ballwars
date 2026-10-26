import 'dart:convert';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PostgREST inspects response.request.method when handling maybeSingle GETs.
// Its JSON response is a row array; maybeSingle unwraps it inside the SDK.
void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());

  test(
    'successful power-up save refreshes the offline settings backup',
    () async {
      var offline = false;
      final row = <String, dynamic>{
        'id': 1,
        'headline': 'WHO WINS?',
        'theme': 'midnight',
        'power_ups': <String, dynamic>{},
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (offline) return http.Response('offline', 503, request: request);
          if (request.method == 'PATCH') {
            row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode([row]),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([row]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
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
    },
  );

  test(
    'missing power-up column cannot silently discard changed numbers',
    () async {
      var writes = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.method == 'PATCH') writes++;
          return http.Response(
            jsonEncode([
              {'id': 1, 'headline': 'WHO WINS?', 'theme': 'midnight'},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseAppSettingsRepository(client);
      final loaded = await repository.load();
      await expectLater(
        repository.save(
          loaded.copyWith(
            powerUps: PowerUpConfig.defaults.withValue('dmg.pistol', 23),
          ),
        ),
        throwsStateError,
      );
      expect(writes, 0);
    },
  );

  test(
    'skill library is confirmed by the server and restored offline',
    () async {
      var offline = false;
      final row = <String, dynamic>{
        'id': 1,
        'headline': 'WHO WINS?',
        'theme': 'midnight',
        'power_ups': <String, dynamic>{},
        'skill_library': SkillLibrary.defaults.toJson(),
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (offline) return http.Response('offline', 503, request: request);
          if (request.method == 'PATCH') {
            row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response(
            jsonEncode([row]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseAppSettingsRepository(client);
      final loaded = await repository.load();
      final edited = loaded.skillLibrary.withDefinition(
        loaded.skillLibrary
            .builtIn(PowerUpKind.pistol, loaded.powerUps)
            .copyWith(arsenalDamage: 31),
        loaded.powerUps,
      );
      await repository.save(
        loaded.copyWith(
          skillLibrary: edited,
          powerUps: edited.applyTo(loaded.powerUps),
        ),
      );
      offline = true;
      final reopened = await SupabaseAppSettingsRepository(client).load();
      expect(reopened.powerUps.arenaDamage(PowerUpKind.pistol), 31);
      expect(reopened.skillLibrary.overrides, hasLength(1));
    },
  );

  test('two clients synchronize the shared skill library row', () async {
    final row = <String, dynamic>{
      'id': 1,
      'headline': 'WHO WINS?',
      'theme': 'midnight',
      'power_ups': <String, dynamic>{},
      'skill_library': SkillLibrary.defaults.toJson(),
    };
    Future<http.Response> handler(http.Request request) async {
      if (request.method == 'PATCH') {
        row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return http.Response(
        jsonEncode([row]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }

    final browserClient = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient(handler),
    );
    final phoneClient = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient(handler),
    );
    addTearDown(browserClient.dispose);
    addTearDown(phoneClient.dispose);
    final browser = SupabaseAppSettingsRepository(browserClient);
    final phone = SupabaseAppSettingsRepository(phoneClient);
    final browserSettings = await browser.load();
    final custom = browserSettings.skillLibrary
        .create('Shared Pulse', PowerUpKind.apple)
        .copyWith(enabled: true);
    final changed = browserSettings.skillLibrary.withDefinition(
      custom,
      browserSettings.powerUps,
    );
    await browser.save(browserSettings.copyWith(skillLibrary: changed));

    final loadedOnPhone = await phone.load();
    expect(loadedOnPhone.skillLibrary.custom.single.name, 'Shared Pulse');
  });

  test('missing skill library column rejects custom skill changes', () async {
    var writes = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') writes++;
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'headline': 'WHO WINS?',
              'theme': 'midnight',
              'power_ups': {},
            },
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAppSettingsRepository(client);
    final loaded = await repository.load();
    final custom = loaded.skillLibrary.duplicate(
      loaded.skillLibrary.builtIn(PowerUpKind.pistol, loaded.powerUps),
      'Custom Pistol',
    );
    final changed = loaded.skillLibrary.withDefinition(custom, loaded.powerUps);
    await expectLater(
      repository.save(loaded.copyWith(skillLibrary: changed)),
      throwsStateError,
    );
    expect(writes, 0);
  });
  test(
    'missing branding columns cannot silently discard edited branding',
    () async {
      var writes = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.method == 'PATCH') writes++;
          return http.Response(
            jsonEncode([
              {'id': 1, 'headline': 'WHO WINS?', 'theme': 'midnight'},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseAppSettingsRepository(client);
      final loaded = await repository.load();
      await expectLater(
        repository.save(loaded.copyWith(arenaTitle: 'My Arena')),
        throwsStateError,
      );
      expect(writes, 0);
    },
  );

  test(
    'confirmed branding survives a fresh repository and offline load',
    () async {
      var offline = false;
      final row = <String, dynamic>{
        'id': 1,
        'headline': 'WHO WINS?',
        'theme': 'midnight',
        'arena_title': 'dbsuarez',
        'arena_subtitle': 'bakbakan na',
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (offline) return http.Response('offline', 503, request: request);
          if (request.method == 'PATCH') {
            row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response(
            jsonEncode([row]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseAppSettingsRepository(client);
      final loaded = await repository.load();
      await repository.save(
        loaded.copyWith(arenaTitle: 'My Arena', arenaSubtitle: 'Fight!'),
      );
      offline = true;
      final reopened = await SupabaseAppSettingsRepository(client).load();
      expect(reopened.arenaTitle, 'My Arena');
      expect(reopened.arenaSubtitle, 'Fight!');
    },
  );

  test('arena decoration is persisted and restored offline', () async {
    var offline = false;
    final row = <String, dynamic>{
      'id': 1,
      'headline': 'WHO WINS?',
      'theme': 'midnight',
      'arena_decoration': 'defaultArena',
    };
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (offline) return http.Response('offline', 503, request: request);
        if (request.method == 'PATCH') {
          row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return http.Response(
          jsonEncode([row]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAppSettingsRepository(client);
    final loaded = await repository.load();
    await repository.save(
      loaded.copyWith(arenaDecoration: ArenaDecoration.wilderness),
    );
    offline = true;
    final reopened = await SupabaseAppSettingsRepository(client).load();
    expect(reopened.arenaDecoration, ArenaDecoration.wilderness);
  });
}

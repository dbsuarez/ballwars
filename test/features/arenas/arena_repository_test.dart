import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/arenas/domain/arena_catalog.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  for (final migrated in [false, true]) {
    test(
      'arena catalog save, cross-device load and offline cache migrated=$migrated',
      () async {
        var offline = false;
        final row = <String, dynamic>{
          'id': 1,
          'headline': 'WHO WINS?',
          'theme': 'midnight',
          if (migrated) 'arena_catalog': const ArenaCatalog().toJson(),
        };
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            if (offline) throw http.ClientException('offline');
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
        final repo = SupabaseAppSettingsRepository(client);
        final initial = await repo.load();
        final catalog = const ArenaCatalog()
            .withArena(const ArenaDefinition(id: 'court', name: 'Court'))
            .withDefault('court');
        if (!migrated) {
          await expectLater(
            repo.save(initial.copyWith(arenaCatalog: catalog)),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('029_arena_catalog.sql'),
              ),
            ),
          );
          return;
        }
        await repo.save(initial.copyWith(arenaCatalog: catalog));
        final remote = await SupabaseAppSettingsRepository(client).load();
        expect(remote.arenaCatalog.find('court')!.name, 'Court');
        offline = true;
        final cached = await SupabaseAppSettingsRepository(client).load();
        expect(cached.arenaCatalog.defaultId, 'court');
      },
    );
  }
  test('server dropping arena edits cannot be reported as saved', () async {
    final row = <String, dynamic>{
      'id': 1,
      'headline': 'WHO WINS?',
      'theme': 'midnight',
      'arena_catalog': const ArenaCatalog().toJson(),
    };
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>
            ..remove('arena_catalog');
          row.addAll(body);
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
    final repo = SupabaseAppSettingsRepository(client);
    final initial = await repo.load();
    await expectLater(
      repo.save(
        initial.copyWith(
          arenaCatalog: const ArenaCatalog().withArena(
            const ArenaDefinition(id: 'court', name: 'Court'),
          ),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('did not confirm'),
        ),
      ),
    );
  });
}

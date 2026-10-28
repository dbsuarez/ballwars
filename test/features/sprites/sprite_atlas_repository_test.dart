import 'dart:convert';
import 'dart:typed_data';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/sprites/data/sprite_atlas_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'custom_sprite_loader_test.dart' show custom;
import 'sprite_import_screen_test.dart' show imageBytes;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final duplicate in [false, true]) {
    test(
      'restore with original UUID ${duplicate ? 'never overwrites an existing row' : 'inserts a missing row'}',
      () async {
        await TestWidgetsFlutterBinding.instance.runAsync(() async {
          const id = '11111111-1111-1111-1111-111111111111';
          final requests = <http.Request>[];
          final client = SupabaseClient(
            'https://example.supabase.co',
            'key',
            httpClient: MockClient((r) async {
              requests.add(r);
              Object body;
              var code = 200;
              if (r.url.path.contains('/rest/v1/')) {
                if (duplicate) {
                  body = {
                    'message': 'duplicate ID',
                    'code': '23505',
                    'details': 'exists',
                    'hint': null,
                  };
                  code = 409;
                } else {
                  body = jsonDecode(r.body);
                }
              } else if (r.method == 'DELETE') {
                body = [];
              } else {
                body = {'Key': r.url.path.split('/object/').last};
              }
              return http.Response(
                jsonEncode(body),
                code,
                headers: {'content-type': 'application/json'},
                request: r,
              );
            }),
          );
          final operation = SupabaseSpriteAtlasRepository(client).save(
            id: id,
            restoreMissing: true,
            name: 'Restored',
            sheet: await imageBytes(16),
            contentType: 'image/png',
            atlas: custom('a').atlas,
          );
          if (duplicate) {
            await expectLater(operation, throwsA(isA<PostgrestException>()));
          } else {
            expect((await operation).id, id);
          }
          final table = requests.singleWhere(
            (r) => r.url.path.contains('/rest/v1/'),
          );
          expect(table.method, 'POST');
          expect(table.headers['Prefer'], isNot(contains('merge-duplicates')));
          expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
          expect(jsonDecode(table.body)['id'], id);
          await client.dispose();
        });
      },
    );
  }
  for (final succeeds in [true, false]) {
    test(
      'replacement ${succeeds ? 'publishes then removes old sheet' : 'failure removes only unreferenced new upload'}',
      () async {
        await TestWidgetsFlutterBinding.instance.runAsync(() async {
          final requests = <http.Request>[];
          Map<String, dynamic>? updated;
          final old = custom('a');
          final client = SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            httpClient: MockClient((r) async {
              requests.add(r);
              Object body;
              var status = 200;
              if (r.method == 'GET') {
                body = {
                  'sheet_path': old.sheetPath,
                  'updated_at': old.updatedAt.toIso8601String(),
                };
              } else if (r.method == 'PATCH') {
                updated = jsonDecode(r.body) as Map<String, dynamic>;
                body = succeeds
                    ? updated!
                    : {
                        'message': 'Atlas changed',
                        'code': 'PGRST116',
                        'details': '0 rows',
                        'hint': null,
                      };
                status = succeeds ? 200 : 406;
              } else if (r.method == 'DELETE') {
                body = [];
              } else {
                body = {'Key': r.url.path.split('/object/').last};
              }
              return http.Response(
                jsonEncode(body),
                status,
                headers: {'content-type': 'application/json'},
                request: r,
              );
            }),
          );
          final operation = SupabaseSpriteAtlasRepository(client).save(
            id: old.id,
            expectedUpdatedAt: old.updatedAt,
            name: old.name,
            sheet: await imageBytes(16),
            contentType: 'image/png',
            atlas: old.atlas,
          );
          if (succeeds) {
            final saved = await operation;
            expect(saved.id, old.id);
            expect(saved.sheetPath, isNot(old.sheetPath));
            expect(
              (await OfflineStore.instance.read(
                SupabaseSpriteAtlasRepository.cacheKey,
              )),
              isNotNull,
            );
          } else {
            await expectLater(operation, throwsA(isA<PostgrestException>()));
          }
          final patch = requests.singleWhere((r) => r.method == 'PATCH');
          expect(patch.url.queryParameters['updated_at'], startsWith('eq.'));
          final removed =
              jsonDecode(requests.singleWhere((r) => r.method == 'DELETE').body)
                  as Map;
          expect(removed['prefixes'], [
            succeeds ? old.sheetPath : updated!['sheet_path'],
          ]);
          await client.dispose();
        });
      },
    );
  }
  test('stale replacement is rejected before uploading any bytes', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final methods = <String>[];
      final old = custom('a');
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((r) async {
          methods.add(r.method);
          return http.Response(
            jsonEncode({
              'sheet_path': old.sheetPath,
              'updated_at': old.updatedAt
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      await expectLater(
        SupabaseSpriteAtlasRepository(client).save(
          id: old.id,
          expectedUpdatedAt: old.updatedAt,
          name: old.name,
          sheet: await imageBytes(16),
          contentType: 'image/png',
          atlas: old.atlas,
        ),
        throwsStateError,
      );
      expect(methods, ['GET']);
      await client.dispose();
    });
  });
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  test('offline manifest read falls back to last successful catalog', () async {
    final atlas = custom('a');
    await OfflineStore.instance.write(
      SupabaseSpriteAtlasRepository.cacheKey,
      utf8.encode(jsonEncode([atlas.toJson()])),
    );
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((_) async => throw StateError('offline')),
    );
    final repo = SupabaseSpriteAtlasRepository(client);
    final saved = await repo.list();
    expect(saved.single.toJson(), atlas.toJson());
    await client.dispose();
  });
  test('oversized image is refused before any server call', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );
    final repo = SupabaseSpriteAtlasRepository(client);
    await expectLater(
      repo.save(
        name: 'bad',
        sheet: Uint8List(4194305),
        contentType: 'image/png',
        atlas: custom('a').atlas,
      ),
      throwsFormatException,
    );
    expect(calls, 0);
    await client.dispose();
  });
  test(
    'RLS refusing delete is reported instead of appearing successful',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({'sheet_path': 'a/a.png'}),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode({
              'message': 'No rows',
              'code': 'PGRST116',
              'details': '0 rows',
              'hint': null,
            }),
            406,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await expectLater(
        SupabaseSpriteAtlasRepository(client).delete('a'),
        throwsA(isA<PostgrestException>()),
      );
      await client.dispose();
    },
  );
}

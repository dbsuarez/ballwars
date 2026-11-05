import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/custom_groups/data/custom_group_repository.dart';

void main() {
  test(
    'every group read orders equal ball positions deterministically by ID',
    () async {
      OfflineStore.instance = MemoryOfflineStore();
      var reads = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/rest/v1/ball_groups');
          final order = request.url.queryParameters['group_balls.order'];
          expect(order, startsWith('position.desc'));
          expect(order, contains(',id.desc'));
          reads++;
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'access',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'refresh',
          'user': {
            'id': 'owner-1',
            'aud': 'authenticated',
            'created_at': '2026-10-31T00:00:00Z',
            'is_anonymous': true,
          },
        }),
      );
      final repository = SupabaseCustomGroupRepository(client);
      await repository.myGroups();
      await repository.allGroups();
      await repository.savedGroups();
      await repository.group('g1');
      await repository.packExtras();
      expect(reads, 5);
    },
  );
}

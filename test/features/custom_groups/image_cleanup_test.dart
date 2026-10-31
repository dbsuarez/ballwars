import 'dart:convert';
import 'dart:typed_data';

import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/custom_groups/data/custom_group_repository.dart';
import 'package:ballwars/features/custom_groups/domain/custom_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = 'owner-1';

String _session() => jsonEncode({
  'access_token': 'access',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh',
  'user': {
    'id': _owner,
    'aud': 'authenticated',
    'created_at': '2026-10-31T00:00:00Z',
    'is_anonymous': true,
  },
});

CustomBall _ball(String image) => CustomBall(
  id: CustomGroup.ballId('ball-$image'),
  name: 'Ball $image',
  imageUrl:
      'https://example.supabase.co/storage/v1/object/public/ball-images/$_owner/$image.png',
  imageStyle: BallImageStyle.logo,
  primaryColor: const Color(0xFF8E44AD),
  glowColor: const Color(0xFFC39BD3),
);

/// A client whose HTTP traffic is answered by [handler] and whose session is
/// already in place, so no auth request is needed.
Future<SupabaseClient> _client(
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    httpClient: MockClient(handler),
  );
  addTearDown(client.dispose);
  await client.auth.setInitialSession(_session());
  return client;
}

http.Response _json(Object body, http.Request request) => http.Response(
  jsonEncode(body),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _row(String image) => {
  'id': 'ball-$image',
  'name': 'Ball $image',
  'image_path': '$_owner/$image.png',
  'image_style': 'logo',
  'color': '#8E44AD',
  'position': 1,
  'gender': 'none',
};

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());

  test('a failed image cleanup does not undo a group deletion', () async {
    var deleted = false;
    final removed = <String>[];
    final client = await _client((request) async {
      if (request.method == 'DELETE' &&
          request.url.path == '/rest/v1/ball_groups') {
        deleted = true;
        return http.Response('', 204, request: request);
      }
      if (request.method == 'DELETE' &&
          request.url.path == '/storage/v1/object/ball-images') {
        removed.addAll(
          (jsonDecode(request.body)['prefixes'] as List).cast<String>(),
        );
        return http.Response(
          '{"statusCode":"500","error":"Storage unavailable"}',
          500,
          request: request,
        );
      }
      fail('unexpected ${request.method} ${request.url}');
    });
    final repository = SupabaseCustomGroupRepository(client);
    final group = CustomGroup(
      id: 'g1',
      name: 'Barkada',
      isPublic: true,
      balls: [_ball('one'), _ball('two')],
    );

    await repository.deleteGroup(group);

    expect(deleted, isTrue);
    expect(removed, ['$_owner/one.png', '$_owner/two.png']);
  });

  test('a failed old-image delete keeps the edit and the new picture', () async {
    String? uploaded;
    final removed = <String>[];
    final client = await _client((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/rest/v1/group_balls') {
        return _json({'owner': _owner}, request);
      }
      if (request.method == 'POST' &&
          request.url.path.startsWith('/storage/v1/object/ball-images/')) {
        uploaded = request.url.path.replaceFirst(
          '/storage/v1/object/ball-images/',
          '',
        );
        return _json({'Key': 'ball-images/$uploaded'}, request);
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/rest/v1/group_balls') {
        return _json({..._row('new'), 'image_path': uploaded}, request);
      }
      if (request.method == 'DELETE' &&
          request.url.path == '/storage/v1/object/ball-images') {
        removed.addAll(
          (jsonDecode(request.body)['prefixes'] as List).cast<String>(),
        );
        return http.Response(
          '{"statusCode":"500","error":"Storage unavailable"}',
          500,
          request: request,
        );
      }
      fail('unexpected ${request.method} ${request.url}');
    });
    final repository = SupabaseCustomGroupRepository(client);

    final updated = await repository.updateBall(
      _ball('old'),
      name: 'Renamed',
      style: BallImageStyle.logo,
      color: const Color(0xFF8E44AD),
      png: Uint8List.fromList(const [1, 2, 3]),
    );

    expect(uploaded, isNotNull);
    expect(updated.imageUrl, contains(uploaded!));
    expect(removed, ['$_owner/old.png']);
    expect(removed, isNot(contains(uploaded)));
  });
}

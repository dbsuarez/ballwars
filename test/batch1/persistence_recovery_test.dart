import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/core/offline/persistent_preferences_store.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/custom_groups/data/custom_group_repository.dart';
import 'package:ballwars/features/custom_groups/domain/custom_group.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';

class TestStore extends MemoryOfflineStore {
  bool failWrites = false, failReads = false, discardWrites = false;
  @override
  Future<void> write(String key, Uint8List value) async {
    if (failWrites) throw StateError('Disk full');
    if (!discardWrites) await super.write(key, value);
  }

  @override
  Future<Uint8List?> read(String key) async {
    if (failReads) throw StateError('Unreadable storage');
    return super.read(key);
  }
}

class Groups implements CustomGroupRepository {
  Groups(this.id);
  String? id;
  int reads = 0;
  @override
  String? get userId => id;
  @override
  Future<List<CustomGroup>> myGroups() async {
    reads++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String session(String id) => jsonEncode({
  'access_token': 'access',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh',
  'user': {
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-11-04T00:00:00Z',
    'is_anonymous': true,
  },
});
Future<SupabaseClient> client(
  String id,
  Future<http.Response> Function(http.Request) handler,
) async {
  final c = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    httpClient: MockClient(handler),
  );
  addTearDown(c.dispose);
  await c.auth.setInitialSession(session(id));
  return c;
}

http.Response jsonResponse(
  http.Request request,
  Object body, {
  int status = 200,
}) => http.Response(
  jsonEncode(body),
  status,
  request: request,
  headers: {'content-type': 'application/json'},
);
const row = {
  'id': 'private',
  'name': 'Private group',
  'owner': 'admin',
  'is_public': false,
  'group_balls': [],
};
Uri replay(int seed) =>
    Uri.parse('https://example.com/?seed=$seed&balls=p.a,p.b');

void main() {
  late TestStore store;
  setUp(() {
    store = TestStore();
    OfflineStore.instance = store;
  });
  test(
    'durable replay mutations fail visibly, preserve old data and recover on retry',
    () async {
      await SavedReplayStore.add(replay(1), contestantNames: ['A', 'B']);
      final first = (await SavedReplayStore.load()).single;
      store.failWrites = true;
      await expectLater(SavedReplayStore.add(replay(2)), throwsStateError);
      await expectLater(
        SavedReplayStore.rename(first.id, 'Changed'),
        throwsStateError,
      );
      await expectLater(SavedReplayStore.remove(first.id), throwsStateError);
      await expectLater(
        SavedReplayStore.attachShareUri(
          first.id,
          Uri.parse('https://example.com/?r=abc1234'),
        ),
        throwsStateError,
      );
      store.failWrites = false;
      expect((await SavedReplayStore.load()).single.toJson(), first.toJson());
      await SavedReplayStore.add(replay(2));
      expect(await SavedReplayStore.load(), hasLength(2));
    },
  );
  test(
    'unconfirmed and unreadable replay records never report a durable save',
    () async {
      await SavedReplayStore.add(replay(1));
      store.discardWrites = true;
      await expectLater(SavedReplayStore.add(replay(2)), throwsStateError);
      store.discardWrites = false;
      store.failReads = true;
      await expectLater(SavedReplayStore.add(replay(3)), throwsStateError);
      store.failReads = false;
      expect((await SavedReplayStore.load()).single.uri, replay(1).toString());
    },
  );
  test(
    'corrupt replay data is kept instead of overwritten with an empty list',
    () async {
      await DevicePrefs.writeRequired('saved-replays', 'broken json');
      await expectLater(SavedReplayStore.add(replay(2)), throwsStateError);
      expect(await DevicePrefs.readRequired('saved-replays'), 'broken json');
    },
  );
  test(
    'concurrent replay mutations preserve additions, names and share metadata',
    () async {
      await Future.wait([
        SavedReplayStore.add(replay(1)),
        SavedReplayStore.add(replay(2)),
      ]);
      final entries = await SavedReplayStore.load();
      expect(entries, hasLength(2));
      await Future.wait([
        SavedReplayStore.rename(entries.first.id, 'My replay'),
        SavedReplayStore.attachShareUri(
          entries.first.id,
          Uri.parse('https://example.com/?r=abc1234'),
        ),
        SavedReplayStore.add(replay(3)),
      ]);
      final next = await SavedReplayStore.load();
      expect(next, hasLength(3));
      final changed = next.singleWhere((e) => e.id == entries.first.id);
      expect(changed.name, 'My replay');
      expect(changed.shareUri, contains('abc1234'));
    },
  );
  test(
    'best effort preference writes remain safe after a failed required write',
    () async {
      store.failWrites = true;
      await expectLater(
        DevicePrefs.writeRequired('strict', 'no'),
        throwsStateError,
      );
      await DevicePrefs.write('speed', 1);
      store.failWrites = false;
      await DevicePrefs.writeRequired('strict', 'yes');
      expect(await DevicePrefs.readRequired('strict'), 'yes');
    },
  );
  test(
    'group adoption retries after failure and coalesces concurrent requests',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      final account = Groups('admin');
      final r = AccountAwareCustomGroupRepository(
        device: Groups('device'),
        account: account,
        isAccountActive: () async => true,
        adoptGroupsFrom: (_) async {
          calls++;
          if (calls == 1) throw StateError('Temporary failure');
          await gate.future;
          return 1;
        },
      );
      await expectLater(r.myGroups(), throwsStateError);
      final a = r.myGroups(), b = r.myGroups();
      await pumpEventQueue();
      expect(calls, 2);
      gate.complete();
      await Future.wait([a, b]);
      await r.myGroups();
      expect(calls, 2);
      expect(account.reads, 3);
    },
  );
  test(
    'adoption follows source/target accounts and resets after logout',
    () async {
      final device = Groups('device'), account = Groups('one');
      var active = true;
      final calls = <String>[];
      final r = AccountAwareCustomGroupRepository(
        device: device,
        account: account,
        isAccountActive: () async => active,
        adoptGroupsFrom: (source) async {
          calls.add('$source:${account.id}');
          return 0;
        },
      );
      await r.myGroups();
      account.id = 'two';
      await r.myGroups();
      device.id = 'other-device';
      await r.myGroups();
      active = false;
      await r.myGroups();
      active = true;
      await r.myGroups();
      expect(calls, [
        'device:one',
        'device:two',
        'other-device:two',
        'other-device:two',
      ]);
    },
  );
  test(
    'an account switch during adoption does not return another account results',
    () async {
      final account = Groups('one');
      final gate = Completer<int>();
      final r = AccountAwareCustomGroupRepository(
        device: Groups('device'),
        account: account,
        isAccountActive: () async => true,
        adoptGroupsFrom: (_) => gate.future,
      );
      final pending = r.myGroups();
      final failure = expectLater(pending, throwsStateError);
      await pumpEventQueue();
      account.id = 'two';
      gate.complete(0);
      await failure;
      expect(account.reads, 0);
    },
  );
  test(
    'group cache survives HTTP connectivity failures but never hides RLS errors',
    () async {
      var mode = 'online';
      final c = await client('device', (req) async {
        if (mode == 'offline') throw http.ClientException('Failed to fetch');
        if (mode == 'denied') {
          return jsonResponse(req, {
            'code': '42501',
            'message': 'Denied',
          }, status: 403);
        }
        return jsonResponse(req, [row]);
      });
      final r = SupabaseCustomGroupRepository(c);
      expect(await r.myGroups(), hasLength(1));
      mode = 'offline';
      expect(await r.myGroups(), hasLength(1));
      mode = 'denied';
      await expectLater(r.myGroups(), throwsA(isA<PostgrestException>()));
    },
  );
  test('fresh groups remain usable when local cache writes fail', () async {
    final c = await client('device', (req) async => jsonResponse(req, [row]));
    store.failWrites = true;
    expect(await SupabaseCustomGroupRepository(c).myGroups(), hasLength(1));
  });
  test(
    'admin all-groups cache cannot cross identities or reuse old unscoped cache',
    () async {
      final admin = await client(
        'admin',
        (req) async => jsonResponse(req, [row]),
      );
      await SupabaseCustomGroupRepository(admin).allGroups();
      await store.write(
        'groups:all',
        Uint8List.fromList(utf8.encode(jsonEncode([row]))),
      );
      final anon = await client(
        'anonymous',
        (req) async => throw const SocketException('Offline'),
      );
      await expectLater(
        SupabaseCustomGroupRepository(anon).allGroups(),
        throwsStateError,
      );
      final same = await client(
        'admin',
        (req) async => throw const SocketException('Offline'),
      );
      expect(
        await SupabaseCustomGroupRepository(same).allGroups(),
        hasLength(1),
      );
    },
  );
  test(
    'stale settings saves conflict without overwriting newer edits; reload enables retry',
    () async {
      final settings = <String, dynamic>{
        'id': 1,
        'headline': 'Original',
        'theme': 'midnight',
        'ball_appearance': <String, Object>{},
        'updated_at': '2026-11-04T00:00:00Z',
      };
      var rejected = 0;
      final c = await client('admin', (req) async {
        if (req.method == 'PATCH') {
          if (req.url.queryParameters['updated_at'] !=
              'eq.${settings['updated_at']}') {
            rejected++;
            return jsonResponse(req, []);
          }
          settings.addAll(jsonDecode(req.body) as Map<String, dynamic>);
        }
        return jsonResponse(req, [settings]);
      });
      final a = SupabaseAppSettingsRepository(c),
          b = SupabaseAppSettingsRepository(c);
      final first = await a.load(), stale = await b.load();
      await a.save(first.copyWith(headline: 'New headline'));
      await expectLater(
        b.save(stale.copyWith(themeId: 'forest')),
        throwsStateError,
      );
      expect(rejected, 1);
      expect(settings['headline'], 'New headline');
      expect(settings['theme'], 'midnight');
      final fresh = await b.load();
      await b.save(fresh.copyWith(themeId: 'forest'));
      expect(settings['headline'], 'New headline');
      expect(settings['theme'], 'forest');
      await b.save((await b.load()).copyWith(headline: 'Final'));
      expect(settings['headline'], 'Final');
    },
  );
  test(
    'blocked browser persistence never claims a replay was saved in memory',
    () async {
      OfflineStore.instance = PersistentPreferencesStore(
        resources: MemoryOfflineStore(),
        readPersistent: (_) async => null,
        writePersistent: (_, _) async => throw StateError('Quota exceeded'),
      );
      await expectLater(SavedReplayStore.add(replay(1)), throwsStateError);
      expect(await SavedReplayStore.load(), isEmpty);
    },
  );
  test(
    'an empty authoritative replay list does not resurrect a legacy replay',
    () async {
      await DevicePrefs.writeRequired('saved-replay', replay(1));
      expect(await SavedReplayStore.load(), hasLength(1));
      await SavedReplayStore.remove('legacy');
      await DevicePrefs.write('saved-replay', replay(1));
      expect(await SavedReplayStore.load(), isEmpty);
    },
  );
}

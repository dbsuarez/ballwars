import 'dart:async';
import 'dart:convert';

import 'package:ballwars/core/auth/device_session_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A session as GoTrue hands it out, so the guard's encoding is the real one.
Session _session(String id, {required bool anonymous}) => Session.fromJson({
  'access_token': 'access-$id',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-$id',
  'user': {
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-10-31T00:00:00Z',
    'is_anonymous': anonymous,
  },
})!;

String? _userId(String sessionJson) =>
    (jsonDecode(sessionJson)['user'] as Map)['id'] as String?;

void main() {
  late StreamController<AuthState> events;
  late List<String> restored;
  late Session? current;
  late DeviceSessionGuard guard;

  DeviceSessionGuard build() => DeviceSessionGuard(
    currentSession: () => current,
    events: events.stream,
    restore: (sessionJson) async => restored.add(sessionJson),
  );

  setUp(() {
    events = StreamController<AuthState>.broadcast();
    restored = [];
    current = null;
  });

  tearDown(() async {
    await guard.dispose();
    await events.close();
  });

  test('a broadcast admin sign-in puts the device session back', () async {
    current = _session('device', anonymous: true);
    guard = build();

    events.add(
      AuthState(
        AuthChangeEvent.signedIn,
        _session('admin', anonymous: false),
        fromBroadcast: true,
      ),
    );
    await pumpEventQueue();

    expect(restored, hasLength(1));
    expect(_userId(restored.single), 'device');
  });

  test('a broadcast sign-out puts the device session back', () async {
    current = _session('device', anonymous: true);
    guard = build();

    events.add(AuthState(AuthChangeEvent.signedOut, null, fromBroadcast: true));
    await pumpEventQueue();

    expect(restored, hasLength(1));
    expect(_userId(restored.single), 'device');
  });

  test(
    'the device client\'s own anonymous sign-in becomes the snapshot',
    () async {
      current = _session('device', anonymous: true);
      guard = build();

      events.add(
        AuthState(
          AuthChangeEvent.signedIn,
          _session('device-2', anonymous: true),
        ),
      );
      await pumpEventQueue();
      expect(restored, isEmpty);
      expect(_userId(guard.deviceSession!), 'device-2');

      events.add(
        AuthState(
          AuthChangeEvent.signedIn,
          _session('admin', anonymous: false),
          fromBroadcast: true,
        ),
      );
      await pumpEventQueue();

      expect(restored, hasLength(1));
      expect(_userId(restored.single), 'device-2');
    },
  );

  test('a refresh broadcast from the device\'s other tab is ignored', () async {
    current = _session('device', anonymous: true);
    guard = build();

    events.add(
      AuthState(
        AuthChangeEvent.tokenRefreshed,
        _session('device', anonymous: true),
        fromBroadcast: true,
      ),
    );
    await pumpEventQueue();

    expect(restored, isEmpty);
  });

  test('a real device sign-out is not resurrected', () async {
    current = _session('device', anonymous: true);
    guard = build();

    events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await pumpEventQueue();
    expect(guard.deviceSession, isNull);

    events.add(
      AuthState(
        AuthChangeEvent.signedIn,
        _session('admin', anonymous: false),
        fromBroadcast: true,
      ),
    );
    await pumpEventQueue();

    expect(restored, isEmpty);
  });

  test('there is nothing to restore before the device has a session', () async {
    guard = build();

    events.add(
      AuthState(
        AuthChangeEvent.signedIn,
        _session('admin', anonymous: false),
        fromBroadcast: true,
      ),
    );
    await pumpEventQueue();

    expect(restored, isEmpty);
    expect(guard.deviceSession, isNull);
  });

  test('dispose stops watching', () async {
    current = _session('device', anonymous: true);
    guard = build();
    await guard.dispose();

    events.add(
      AuthState(
        AuthChangeEvent.signedIn,
        _session('admin', anonymous: false),
        fromBroadcast: true,
      ),
    );
    await pumpEventQueue();

    expect(restored, isEmpty);
  });
}

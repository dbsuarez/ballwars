import 'package:ballwars/core/auth/admin_session_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session _session(String id, {required bool anonymous}) => Session.fromJson({
  'access_token': 'access-$id',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-$id',
  'user': {
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-11-04T00:00:00Z',
    'is_anonymous': anonymous,
  },
})!;

void main() {
  test('opt-in admin sessions are eligible for browser persistence', () {
    final admin = _session('admin', anonymous: false);
    final signedIn = AuthState(AuthChangeEvent.signedIn, admin);
    expect(AdminSessionPersistence.shouldSave(signedIn, true), isTrue);
    expect(AdminSessionPersistence.shouldSave(signedIn, false), isFalse);
    expect(AdminSessionPersistence.shouldSave(
      AuthState(AuthChangeEvent.tokenRefreshed, admin), true), isTrue);
  });

  test('never persist anonymous device sessions or broadcast credentials', () {
    expect(AdminSessionPersistence.shouldSave(
      AuthState(AuthChangeEvent.signedIn, _session('device', anonymous: true)),
      true), isFalse);
    expect(AdminSessionPersistence.shouldSave(
      AuthState(AuthChangeEvent.signedIn, _session('admin', anonymous: false),
          fromBroadcast: true), true), isFalse);
    expect(AdminSessionPersistence.shouldSave(
      const AuthState(AuthChangeEvent.signedOut, null), true), isFalse);
  });

  test('local sign-out clears session, device broadcasts never do', () {
    expect(AdminSessionPersistence.shouldClear(
      const AuthState(AuthChangeEvent.signedOut, null)), isTrue);
    expect(AdminSessionPersistence.shouldClear(
      const AuthState(AuthChangeEvent.signedOut, null, fromBroadcast: true)),
      isFalse);
    expect(AdminSessionPersistence.shouldClear(
      AuthState(AuthChangeEvent.signedIn, _session('device', anonymous: true),
          fromBroadcast: true)), isFalse);
  });
}

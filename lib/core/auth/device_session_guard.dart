import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the app's own Supabase client on the device's anonymous session.
///
/// GoTrue gives every client for one project the same browser
/// `BroadcastChannel` (`sb-<project-ref>-auth-token`), and a client that
/// receives another client's `SIGNED_IN` or `SIGNED_OUT` adopts it (or clears
/// itself). The admin signs in on a second client, so on web the device client
/// would otherwise take over the admin session, persist it over the anonymous
/// one, and lose the identity that owns the device's groups and saved replays.
///
/// The guard listens for events that came from another client
/// ([AuthState.fromBroadcast]) and puts the saved anonymous session back. The
/// admin's own client is never touched, and events from the device client
/// itself (anonymous sign-in, token refresh) only update the snapshot.
class DeviceSessionGuard {
  DeviceSessionGuard({
    required Session? Function() currentSession,
    required Stream<AuthState> events,
    required Future<void> Function(String sessionJson) restore,
  }) : _restore = restore {
    _deviceSession = _encode(currentSession());
    _subscription = events.listen(_onEvent, onError: (Object _) {});
  }

  /// Guards [client], the app's own (device) client.
  factory DeviceSessionGuard.forClient(SupabaseClient client) =>
      DeviceSessionGuard(
        currentSession: () => client.auth.currentSession,
        events: client.auth.onAuthStateChange,
        restore: client.auth.setInitialSession,
      );

  final Future<void> Function(String sessionJson) _restore;
  StreamSubscription<AuthState>? _subscription;
  String? _deviceSession;
  bool _restoring = false;

  /// The device session as last seen, or null before the app has one.
  String? get deviceSession => _deviceSession;

  void _onEvent(AuthState state) {
    final session = state.session;
    if (!state.fromBroadcast) {
      // The device client's own event: this is the identity to keep.
      if (session != null) {
        _deviceSession = _encode(session);
      } else if (state.event == AuthChangeEvent.signedOut) {
        // A real sign-out (revoked or expired token): don't resurrect it.
        _deviceSession = null;
      }
      return;
    }
    // Another client broadcast its session: adopt nothing.
    final adminSignedIn = session != null && !session.user.isAnonymous;
    final signedOut =
        session == null && state.event == AuthChangeEvent.signedOut;
    if (adminSignedIn || signedOut) unawaited(_putBack());
  }

  Future<void> _putBack() async {
    final saved = _deviceSession;
    if (saved == null || _restoring) return;
    _restoring = true;
    try {
      await _restore(saved);
    } catch (_) {
      // A failed restore is not fatal: the next group request signs the
      // device in anonymously again (see CustomGroupRepository._userId).
    } finally {
      _restoring = false;
    }
  }

  /// Stops watching. The device client keeps whatever session it has.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static String? _encode(Session? session) {
    if (session == null) return null;
    try {
      return jsonEncode(session.toJson());
    } catch (_) {
      return null;
    }
  }
}

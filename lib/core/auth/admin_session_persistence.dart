import 'package:supabase_flutter/supabase_flutter.dart';

/// Persistence rules for the separate admin Supabase client.
///
/// GoTrue broadcasts auth changes between clients in a browser. A device
/// client's anonymous login/logout is not an admin login/logout and must
/// never replace or erase a remembered admin session on disk.
class AdminSessionPersistence {
  AdminSessionPersistence._();

  /// Store only verified-by-source local, nonanonymous admin-client sessions.
  /// Admin membership itself is checked by SupabaseAdminAuth.isAdmin().
  static bool shouldSave(AuthState state, bool rememberMe) =>
      rememberMe &&
      !state.fromBroadcast &&
      state.session != null &&
      !state.session!.user.isAnonymous;

  /// An explicit local sign-out clears remembered credentials. A broadcast
  /// sign-out from the device client does not.
  static bool shouldClear(AuthState state) =>
      !state.fromBroadcast && state.event == AuthChangeEvent.signedOut;
}

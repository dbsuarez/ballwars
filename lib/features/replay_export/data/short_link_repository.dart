import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Short share links: a shared match is stored in Supabase (`replays`, see
/// supabase/migrations/003) under a random 7-character code, so the link is
/// just `<app>?r=<code>`. Chat apps such as Messenger cut long links off.
abstract class ShortLinkRepository {
  /// Stores the query of a long replay link and returns its new code.
  Future<String> create(Map<String, String> replayQuery);

  /// The long link's query for [code], or null if there's no such replay.
  Future<Map<String, String>?> resolve(String code);
}

class SupabaseShortLinkRepository implements ShortLinkRepository {
  final SupabaseClient _client;
  final math.Random _random;

  SupabaseShortLinkRepository(this._client, {math.Random? random}) : _random = random ?? math.Random.secure();

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  String _newCode() => List.generate(7, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();

  @override
  Future<String> create(Map<String, String> replayQuery) async {
    // Links are tied to the device's (anonymous) account, which the database
    // uses to limit how many one device can make (migration 007).
    if (_client.auth.currentUser == null) await _client.auth.signInAnonymously();
    // 62^7 codes: a clash is very unlikely, but retry a few times anyway.
    for (var attempt = 0; attempt < 4; attempt++) {
      final code = _newCode();
      try {
        await _client.from('replays').insert({
          'id': code,
          'seed': int.parse(replayQuery['seed']!),
          'speed': double.tryParse(replayQuery['speed'] ?? '1') ?? 1,
          'effects': replayQuery['fx'] != '0',
          'balls': replayQuery['balls']!,
        });
        return code;
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // 23505: duplicate key, try another code
      }
    }
    throw StateError('Could not create a short link');
  }

  @override
  Future<Map<String, String>?> resolve(String code) async {
    final row = await _client.from('replays').select('seed, speed, effects, balls').eq('id', code).maybeSingle();
    if (row == null) return null;
    return {
      'seed': '${row['seed']}',
      'speed': '${row['speed']}',
      if (row['effects'] == false) 'fx': '0',
      'balls': row['balls'] as String,
    };
  }
}

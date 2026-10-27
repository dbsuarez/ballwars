import 'dart:convert';

import '../../../core/offline/device_prefs.dart';

class SavedReplay {
  const SavedReplay({
    required this.id,
    required this.savedAt,
    required this.uri,
  });
  final String id;
  final DateTime savedAt;
  final String uri;

  Map<String, Object?> toJson() => {
    'id': id,
    'saved_at': savedAt.toUtc().toIso8601String(),
    'uri': uri,
  };

  static SavedReplay? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final uri = value['uri'];
    final savedAt = DateTime.tryParse('${value['saved_at'] ?? ''}');
    if (id is! String || uri is! String || savedAt == null) return null;
    return SavedReplay(id: id, savedAt: savedAt, uri: uri);
  }
}

class SavedReplayStore {
  static const _key = 'saved-replays';
  static const maxEntries = 20;

  static Future<List<SavedReplay>> load() async {
    final raw = await DevicePrefs.read(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return [for (final item in decoded) ?SavedReplay.fromJson(item)];
        }
      } catch (_) {}
    }
    final legacy = await DevicePrefs.read('saved-replay');
    if (legacy == null || legacy.isEmpty) return const [];
    return [
      SavedReplay(
        id: 'legacy',
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
        uri: legacy,
      ),
    ];
  }

  static Future<void> add(Uri uri) async {
    final now = DateTime.now().toUtc();
    final entries = await load();
    final next = [
      SavedReplay(
        id: now.microsecondsSinceEpoch.toString(),
        savedAt: now,
        uri: uri.toString(),
      ),
      ...entries.where((entry) => entry.uri != uri.toString()),
    ].take(maxEntries).toList();
    await DevicePrefs.write(
      _key,
      jsonEncode([for (final entry in next) entry.toJson()]),
    );
    await DevicePrefs.write('saved-replay', uri.toString());
  }

  static Future<void> remove(String id) async {
    final next = (await load()).where((entry) => entry.id != id).toList();
    await DevicePrefs.write(
      _key,
      jsonEncode([for (final entry in next) entry.toJson()]),
    );
    await DevicePrefs.write('saved-replay', next.firstOrNull?.uri ?? '');
  }
}

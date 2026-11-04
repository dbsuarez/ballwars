import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/offline/device_prefs.dart';

class SavedReplay {
  const SavedReplay({
    required this.id,
    required this.savedAt,
    required this.uri,
    this.name,
    this.shareUri,
  });
  final String id;
  final DateTime savedAt;
  final String uri;
  final String? name;
  final String? shareUri;

  String get displayName => name ?? defaultName(savedAt, const []);

  String get fileName {
    var safe = displayName
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .trim();
    if (safe.toLowerCase().endsWith('.bw')) {
      safe = safe.substring(0, safe.length - 3);
    }
    safe = String.fromCharCodes(
      safe.runes.take(180),
    ).replaceAll(RegExp(r'[. ]+$'), '');
    return '${safe.isEmpty ? 'replay' : safe}.bw';
  }

  /// Local date/time and safe contestant names, suitable for a portable .bw file.
  static String defaultName(DateTime savedAt, Iterable<String> contestants) {
    final time = savedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
    final names = contestants
        .map((name) {
          final safe = name
              .trim()
              .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\s]+'), '_')
              .replaceAll(RegExp(r'[. _]+$'), '');
          return safe.isEmpty
              ? 'ball'
              : String.fromCharCodes(safe.runes.take(24));
        })
        .take(8)
        .join('_');
    return '${stamp}_${names.isEmpty ? 'replay' : names}.bw';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'saved_at': savedAt.toUtc().toIso8601String(),
    'uri': uri,
    if (name != null) 'name': name,
    if (shareUri != null) 'share_uri': shareUri,
  };

  static SavedReplay? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final uri = value['uri'];
    final savedAt = DateTime.tryParse('${value['saved_at'] ?? ''}');
    if (id is! String || uri is! String || savedAt == null) return null;
    return SavedReplay(
      id: id,
      savedAt: savedAt,
      uri: uri,
      name: value['name'] is String ? value['name'] as String : null,
      shareUri: value['share_uri'] is String
          ? value['share_uri'] as String
          : null,
    );
  }
}

class SavedReplayStore {
  static const _key = 'saved-replays';
  static const maxEntries = 20;

  static Future<void>? _mutations;

  static Future<List<SavedReplay>> load() async {
    await _mutations;
    return _load();
  }

  static Future<List<SavedReplay>> _load() async {
    final raw = await DevicePrefs.readRequired(_key);
    if (raw != null && raw.isNotEmpty) {
      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        throw StateError(
          'Saved replays could not be read. The existing record has been kept.',
        );
      }
      if (decoded is! List) {
        throw StateError('Saved replay storage has an unsupported format.');
      }
      final entries = decoded.map(SavedReplay.fromJson).toList();
      if (entries.any((entry) => entry == null)) {
        throw StateError(
          'A saved replay record is damaged. The existing list has been kept.',
        );
      }
      return entries.cast<SavedReplay>();
    }
    final legacy = await DevicePrefs.readRequired('saved-replay');
    if (legacy == null || legacy.isEmpty) return const [];
    return [
      SavedReplay(
        id: 'legacy',
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
        uri: legacy,
      ),
    ];
  }

  static Future<void> _change(
    List<SavedReplay> Function(List<SavedReplay>) change,
  ) {
    final task = (_mutations ?? Future<void>.value()).then((_) async {
      final next = change(await _load());
      await DevicePrefs.writeRequired(
        _key,
        jsonEncode([for (final entry in next) entry.toJson()]),
      );
      // Failure here must not undo or misreport the authoritative list commit.
      await DevicePrefs.write('saved-replay', next.firstOrNull?.uri ?? '');
    });
    late final Future<void> tail;
    tail = task
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_mutations, tail)) _mutations = null;
        });
    _mutations = tail;
    return task.whenComplete(() => tail);
  }

  static Future<void> add(
    Uri uri, {
    Uri? shareUri,
    Iterable<String> contestantNames = const [],
  }) => _change((entries) {
    final now = DateTime.now().toUtc();
    final existing = entries
        .where((entry) => entry.uri == uri.toString())
        .firstOrNull;
    return [
      SavedReplay(
        id: existing?.id ?? const Uuid().v4(),
        savedAt: existing?.savedAt ?? now,
        uri: uri.toString(),
        name:
            existing?.name ??
            SavedReplay.defaultName(existing?.savedAt ?? now, contestantNames),
        shareUri: shareUri?.toString() ?? existing?.shareUri,
      ),
      ...entries.where((entry) => entry.uri != uri.toString()),
    ].take(maxEntries).toList();
  });

  static Future<void> remove(String id) =>
      _change((entries) => entries.where((entry) => entry.id != id).toList());

  static Future<void> rename(String id, String name) => _change(
    (entries) => [
      for (final entry in entries)
        entry.id != id
            ? entry
            : SavedReplay(
                id: entry.id,
                savedAt: entry.savedAt,
                uri: entry.uri,
                name: name.trim().isEmpty ? null : name.trim(),
                shareUri: entry.shareUri,
              ),
    ],
  );

  static Future<void> attachShareUri(String id, Uri uri) => _change(
    (entries) => [
      for (final entry in entries)
        entry.id != id
            ? entry
            : SavedReplay(
                id: entry.id,
                savedAt: entry.savedAt,
                uri: entry.uri,
                name: entry.name,
                shareUri: uri.toString(),
              ),
    ],
  );
}

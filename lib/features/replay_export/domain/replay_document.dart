import 'dart:convert';

/// The portable .bw JSON document and the payload stored behind a short link.
class ReplayDocument {
  ReplayDocument(Map<String, String> query) : query = Map.unmodifiable(query) {
    if (int.tryParse(query['seed'] ?? '') == null ||
        (query['balls'] ?? '').isEmpty ||
        query.length > 64) {
      throw const FormatException('This replay is missing its match data.');
    }
    if (utf8.encode(jsonEncode(toJson())).length > maxBytes) {
      throw const FormatException('This replay is too large to share.');
    }
  }

  static const maxBytes = 524288;
  final Map<String, String> query;

  Map<String, Object> toJson() => {
    'format': 'ballwars-replay',
    'version': 1,
    'query': query,
  };

  String encode() => jsonEncode(toJson());

  factory ReplayDocument.fromJson(Object? json) {
    if (json is! Map ||
        json['format'] != 'ballwars-replay' ||
        json['version'] != 1 ||
        json['query'] is! Map) {
      throw const FormatException('Unsupported Ball Wars replay file.');
    }
    final query = <String, String>{};
    for (final entry in (json['query'] as Map).entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid replay settings.');
      }
      query[entry.key as String] = entry.value as String;
    }
    return ReplayDocument(query);
  }

  factory ReplayDocument.decode(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('This replay file is too large.');
    }
    return ReplayDocument.fromJson(jsonDecode(text));
  }
}

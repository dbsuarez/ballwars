import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import '../../../core/sprites/sprite_atlas.dart';
import '../../../core/sprites/sprite_import.dart';
import '../data/sprite_atlas_repository.dart';

class SpriteBackupEntry {
  const SpriteBackupEntry({
    required this.id,
    required this.name,
    required this.atlas,
    required this.sheet,
    required this.contentType,
    required this.updatedAt,
  });
  final String id, name, contentType;
  final SpriteAtlas atlas;
  final Uint8List sheet;
  final DateTime updatedAt;
  String get digest => sha256.convert(sheet).toString();
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'content_type': contentType,
    'manifest': spriteAtlasJson(atlas),
    'sha256': digest,
    'sheet': base64Encode(sheet),
  };
}

/// Portable, versioned JSON with embedded images, not external download URLs.
class SpriteBackup {
  const SpriteBackup(this.entries, this.createdAt);
  static const maxAtlases = 64,
      maxSheetBytes = 32 * 1024 * 1024,
      maxFileBytes = 48 * 1024 * 1024;
  final List<SpriteBackupEntry> entries;
  final DateTime createdAt;
  Uint8List encode() {
    _checkEntries(entries);
    final bytes = utf8.encode(
      jsonEncode({
        'format': 'ballwars-sprites',
        'version': 1,
        'created_at': createdAt.toUtc().toIso8601String(),
        'atlases': [for (final e in entries) e.toJson()],
      }),
    );
    if (bytes.length > maxFileBytes) {
      throw const FormatException(
        'Backup exceeds 48 MB. Export a smaller selection.',
      );
    }
    return bytes;
  }

  static void _checkEntries(List<SpriteBackupEntry> entries) {
    if (entries.isEmpty || entries.length > maxAtlases) {
      throw const FormatException('A backup contains 1 to 64 uploads.');
    }
    if (entries.map((e) => e.id).toSet().length != entries.length) {
      throw const FormatException('Backup contains duplicate atlas IDs.');
    }
    if (entries.fold<int>(0, (n, e) => n + e.sheet.length) > maxSheetBytes) {
      throw const FormatException(
        'Backup contains more than 32 MB of artwork. Export a smaller selection.',
      );
    }
  }

  static Future<void> validateEntry(SpriteBackupEntry e) async {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(e.id)) {
      throw const FormatException('Backup atlas ID must be a UUID.');
    }
    if (e.name.trim().isEmpty || e.name.length > 80) {
      throw const FormatException(
        'Upload names must contain 1 to 80 characters.',
      );
    }
    final a = e.atlas;
    if (utf8.encode(jsonEncode(spriteAtlasJson(a))).length > 262144 ||
        a.sprites.isEmpty ||
        a.sprites.length > 64 ||
        a.sprites.values.fold<int>(0, (n, s) => n + s.frames.length) > 256 ||
        a.sprites.values.any((s) => s.output > 256 || s.height > 256) ||
        a.sprites.keys.any(
          (name) => !RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(name),
        )) {
      throw const FormatException(
        'Backup contains an invalid sprite manifest or exceeds sprite/frame limits.',
      );
    }
    final image = await validateSpriteSheet(e.sheet, e.contentType);
    try {
      final problems = a.problems(
        sheetSize: Size(image.width.toDouble(), image.height.toDouble()),
      );
      if (problems.isNotEmpty) throw FormatException(problems.join('\n'));
    } finally {
      image.dispose();
    }
  }

  static Future<SpriteBackup> decode(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException(
        'Choose a .bwsprites backup no larger than 48 MB.',
      );
    }
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map ||
          data['format'] != 'ballwars-sprites' ||
          data['version'] != 1) {
        throw const FormatException(
          'Unsupported sprite backup format or version.',
        );
      }
      final raw = data['atlases'];
      if (raw is! List || raw.isEmpty || raw.length > maxAtlases) {
        throw const FormatException('A backup contains 1 to 64 uploads.');
      }
      final entries = <SpriteBackupEntry>[];
      var total = 0;
      for (final row in raw) {
        if (row is! Map ||
            row['sheet'] is! String ||
            (row['sheet'] as String).length > 5592410) {
          throw const FormatException(
            'A backed-up sheet must be no larger than 4 MB.',
          );
        }
        final sheet = base64Decode(row['sheet'] as String);
        total += sheet.length;
        if (total > maxSheetBytes) {
          throw const FormatException(
            'Backup contains more than 32 MB of artwork.',
          );
        }
        final manifest = row['manifest'];
        if (manifest is! Map ||
            utf8.encode(jsonEncode(manifest)).length > 262144 ||
            manifest['sprites'] is! Map ||
            (manifest['sprites'] as Map).length > 64) {
          throw const FormatException(
            'Backup sprite manifest is invalid or too large.',
          );
        }
        var frameCount = 0;
        for (final sprite in (manifest['sprites'] as Map).values) {
          if (sprite is! Map || sprite['frames'] is! List) {
            throw const FormatException('Backup sprite frames are invalid.');
          }
          frameCount += (sprite['frames'] as List).length;
          if (frameCount > 256) {
            throw const FormatException('Backup upload exceeds 256 frames.');
          }
        }
        final e = SpriteBackupEntry(
          id: row['id'] as String,
          name: row['name'] as String,
          atlas: SpriteAtlas.parse(manifest),
          sheet: sheet,
          contentType: row['content_type'] as String,
          updatedAt: DateTime.parse(row['updated_at'] as String),
        );
        if (row['sha256'] != e.digest) {
          throw FormatException(
            '${e.name}: image checksum failed. The backup may be damaged.',
          );
        }
        await validateEntry(e);
        entries.add(e);
      }
      _checkEntries(entries);
      return SpriteBackup(
        entries,
        DateTime.parse(data['created_at'] as String),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid sprite backup. Use an exported .bwsprites file.',
      );
    }
  }
}

String canonicalSpriteManifest(SpriteAtlas atlas) {
  Object? sorted(Object? v) => v is Map
      ? {
          for (final k in v.keys.cast<String>().toList()..sort())
            k: sorted(v[k]),
        }
      : v is List
      ? v.map(sorted).toList()
      : v;
  return jsonEncode(sorted(spriteAtlasJson(atlas)));
}

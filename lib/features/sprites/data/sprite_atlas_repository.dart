import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/sprites/sprite_atlas.dart';
import '../../../core/sprites/sprite_import.dart';

class CustomAtlas {
  const CustomAtlas({
    required this.id,
    required this.name,
    required this.sheetUrl,
    required this.sheetPath,
    required this.atlas,
    required this.updatedAt,
  });
  final String id, name, sheetUrl, sheetPath;
  final SpriteAtlas atlas;
  final DateTime updatedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sheet_url': sheetUrl,
    'sheet_path': sheetPath,
    'manifest': spriteAtlasJson(atlas),
    'updated_at': updatedAt.toIso8601String(),
  };
  factory CustomAtlas.fromJson(Map<String, dynamic> j) => CustomAtlas(
    id: j['id'] as String,
    name: j['name'] as String,
    sheetUrl: j['sheet_url'] as String,
    sheetPath: j['sheet_path'] as String,
    atlas: SpriteAtlas.parse(j['manifest']),
    updatedAt: DateTime.parse(j['updated_at'] as String),
  );
}

abstract class SpriteAtlasRepository {
  Future<List<CustomAtlas>> list();
  Future<CustomAtlas> save({
    String? id,
    DateTime? expectedUpdatedAt,
    bool restoreMissing = false,
    required String name,
    required Uint8List sheet,
    required String contentType,
    required SpriteAtlas atlas,
  });
  Future<void> delete(String id);
}

Future<ui.Image> validateSpriteSheet(
  Uint8List bytes,
  String contentType, {
  bool source = false,
}) async {
  if (bytes.isEmpty || bytes.length > (source ? 16 : 4) * 1024 * 1024) {
    throw FormatException(
      'Sheet must be no larger than ${source ? 16 : 4} MB.',
    );
  }
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71;
  final webp =
      bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
  if (!(png && contentType == 'image/png' ||
      webp && contentType == 'image/webp')) {
    throw const FormatException(
      'Choose a PNG or WebP image, not a renamed JPEG.',
    );
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width > (source ? 8192 : 4096) ||
        descriptor.height > (source ? 8192 : 4096) ||
        descriptor.width * descriptor.height > 16777216) {
      throw FormatException(
        source
            ? 'Source must be at most 8192 pixels per side and 16 megapixels.'
            : 'Sheet must be at most 4096 x 4096 pixels.',
      );
    }
    codec = await descriptor.instantiateCodec();
    if (codec.frameCount != 1) {
      throw const FormatException(
        'Use a static sheet, not an animated image file.',
      );
    }
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

class SupabaseSpriteAtlasRepository implements SpriteAtlasRepository {
  SupabaseSpriteAtlasRepository(this.reader, {SupabaseClient? writer})
    : writer = writer ?? reader;
  final SupabaseClient reader, writer;
  static const cacheKey = 'sprites:atlases';
  List<CustomAtlas> _last = [];
  @override
  Future<List<CustomAtlas>> list() async {
    try {
      final rows = await reader
          .from('sprite_atlases')
          .select()
          .order('name')
          .retry(enabled: false)
          .timeout(const Duration(seconds: 8));
      _last = [
        for (final r in rows)
          CustomAtlas.fromJson({
            ...r,
            'sheet_url': reader.storage
                .from('sprite-sheets')
                .getPublicUrl(r['sheet_path'] as String),
          }),
      ];
      try {
        await OfflineStore.instance.write(
          cacheKey,
          utf8.encode(jsonEncode(_last.map((a) => a.toJson()).toList())),
        );
      } catch (e) {
        debugPrint('Sprite cache write failed: $e');
      }
      return _last;
    } catch (_) {
      final cached = await OfflineStore.instance.read(cacheKey);
      if (cached == null) rethrow;
      return _last = [
        for (final j in jsonDecode(utf8.decode(cached)) as List)
          CustomAtlas.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
    }
  }

  @override
  Future<CustomAtlas> save({
    String? id,
    DateTime? expectedUpdatedAt,
    bool restoreMissing = false,
    required String name,
    required Uint8List sheet,
    required String contentType,
    required SpriteAtlas atlas,
  }) async {
    final image = await validateSpriteSheet(sheet, contentType);
    try {
      final problems = atlas.problems(
        sheetSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
      );
      if (atlas.sprites.isEmpty ||
          atlas.sprites.length > 64 ||
          atlas.sprites.values.fold<int>(0, (n, s) => n + s.frames.length) >
              256) {
        throw const FormatException(
          'Use 1 to 64 sprites and at most 256 frames.',
        );
      }
      if (atlas.sprites.keys.any(
        (s) => !RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(s),
      )) {
        throw const FormatException(
          'Sprite names use lowercase letters, numbers and hyphens (up to 40 characters).',
        );
      }
      if (problems.isNotEmpty) throw FormatException(problems.join('\n'));
    } finally {
      image.dispose();
    }
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw const FormatException(
        'Give the upload a name (1 to 80 characters).',
      );
    }
    final manifest = spriteAtlasJson(atlas);
    if (utf8.encode(jsonEncode(manifest)).length > 262144) {
      throw const FormatException('Manifest must be at most 256 KB.');
    }
    final uuid = const Uuid().v4();
    if (restoreMissing && (id == null || expectedUpdatedAt != null)) {
      throw ArgumentError(
        'Restoring a missing atlas requires its original ID and no existing revision.',
      );
    }
    final atlasId = id ?? uuid;
    String? oldPath;
    if (id != null && !restoreMissing) {
      if (expectedUpdatedAt == null) {
        throw StateError('Refresh the atlas before replacing its artwork.');
      }
      final old = await writer
          .from('sprite_atlases')
          .select('sheet_path, updated_at')
          .eq('id', id)
          .single();
      if (DateTime.parse(old['updated_at'] as String) != expectedUpdatedAt) {
        throw StateError(
          'This atlas changed. Refresh Sprites and retry the replacement.',
        );
      }
      oldPath = old['sheet_path'] as String;
    }
    final path =
        '$atlasId/${const Uuid().v4()}.${contentType == 'image/png' ? 'png' : 'webp'}';
    final bucket = writer.storage.from('sprite-sheets');
    await bucket.uploadBinary(
      path,
      sheet,
      fileOptions: FileOptions(contentType: contentType),
    );
    var published = false;
    try {
      final values = {
        'id': atlasId,
        'name': name.trim(),
        'sheet_path': path,
        'manifest': manifest,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final row = id == null || restoreMissing
          ? await writer.from('sprite_atlases').insert(values).select().single()
          : await writer
                .from('sprite_atlases')
                .update(values)
                .eq('id', id)
                .eq('updated_at', expectedUpdatedAt!.toUtc().toIso8601String())
                .select()
                .single();
      published = true;
      final saved = CustomAtlas.fromJson({
        ...row,
        'sheet_url': reader.storage.from('sprite-sheets').getPublicUrl(path),
      });
      await OfflineStore.instance.write(saved.sheetUrl, sheet).catchError((
        Object e,
      ) {
        debugPrint('Sprite sheet cache write failed: $e');
      });
      _last = [..._last.where((a) => a.id != saved.id), saved];
      try {
        await OfflineStore.instance.write(
          cacheKey,
          utf8.encode(jsonEncode(_last.map((a) => a.toJson()).toList())),
        );
      } catch (e) {
        debugPrint('Saved sprite manifest cache failed: $e');
      }
      if (oldPath != null) {
        try {
          await bucket.remove([oldPath]);
        } catch (e) {
          debugPrint('Replaced sprite sheet cleanup failed: $e');
        }
      }
      return saved;
    } catch (_) {
      if (!published) {
        try {
          await bucket.remove([path]);
        } catch (e) {
          debugPrint('Unreferenced sprite sheet cleanup failed: $e');
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    // Delete the manifest first. Other devices then fall back to built-in art.
    final row = await writer
        .from('sprite_atlases')
        .select('sheet_path')
        .eq('id', id)
        .single();
    await writer
        .from('sprite_atlases')
        .delete()
        .eq('id', id)
        .select('id')
        .single();
    _last.removeWhere((a) => a.id == id);
    try {
      await OfflineStore.instance.write(
        cacheKey,
        utf8.encode(jsonEncode(_last.map((a) => a.toJson()).toList())),
      );
    } catch (e) {
      debugPrint('Deleted sprite manifest cache failed: $e');
    }
    try {
      await writer.storage.from('sprite-sheets').remove([
        row['sheet_path'] as String,
      ]);
    } catch (e) {
      debugPrint('Deleted atlas sheet cleanup failed: $e');
    }
  }
}

Future<Uint8List> fetchSpriteSheet(Uri url) async {
  final key = url.toString();
  final cached = await OfflineStore.instance.read(key);
  if (cached != null) return cached;
  final response = await http.get(url).timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) {
    throw StateError('Sheet download failed (${response.statusCode}).');
  }
  if (response.bodyBytes.length > 4194304) {
    throw const FormatException('Sheet exceeds 4 MB.');
  }
  try {
    await OfflineStore.instance.write(key, response.bodyBytes);
  } catch (e) {
    debugPrint('Sprite sheet cache write failed: $e');
  }
  return response.bodyBytes;
}

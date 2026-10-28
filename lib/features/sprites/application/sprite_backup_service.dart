import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../data/sprite_atlas_repository.dart';
import '../domain/sprite_backup.dart';

enum SpriteRestoreStatus { missing, identical, conflict }

enum SpriteRestoreChoice { skip, restore, replace }

class SpriteRestoreItem {
  SpriteRestoreItem(
    this.entry,
    this.current,
    this.status, {
    this.sameName = false,
  });
  final SpriteBackupEntry entry;
  final CustomAtlas? current;
  final SpriteRestoreStatus status;
  final bool sameName;
  SpriteRestoreChoice get defaultChoice => status == SpriteRestoreStatus.missing
      ? SpriteRestoreChoice.restore
      : SpriteRestoreChoice.skip;
  List<String> get removedNames => current == null
      ? const []
      : current!.atlas.sprites.keys
            .where((id) => !entry.atlas.sprites.containsKey(id))
            .toList();
}

class SpriteRestoreResult {
  final List<String> restored = [], skipped = [];
  final Map<String, String> failed = {};
}

class SpriteBackupService {
  SpriteBackupService(this.repository, {Future<Uint8List> Function(Uri)? fetch})
    : fetch = fetch ?? fetchSpriteSheet;
  final SpriteAtlasRepository repository;
  final Future<Uint8List> Function(Uri) fetch;
  Future<SpriteBackup> export(
    List<CustomAtlas> atlases, {
    void Function(int, int)? progress,
  }) async {
    if (atlases.isEmpty || atlases.length > SpriteBackup.maxAtlases) {
      throw const FormatException('Select 1 to 64 uploads to export.');
    }
    final entries = <SpriteBackupEntry>[];
    var total = 0;
    for (final a in atlases) {
      final bytes = await fetch(Uri.parse(a.sheetUrl));
      total += bytes.length;
      if (total > SpriteBackup.maxSheetBytes) {
        throw const FormatException(
          'Selection exceeds 32 MB of artwork. Export a smaller selection.',
        );
      }
      final e = SpriteBackupEntry(
        id: a.id,
        name: a.name,
        atlas: a.atlas,
        sheet: bytes,
        contentType: a.sheetPath.endsWith('.webp') ? 'image/webp' : 'image/png',
        updatedAt: a.updatedAt,
      );
      await SpriteBackup.validateEntry(e);
      entries.add(e);
      progress?.call(entries.length, atlases.length);
    }
    return SpriteBackup(entries, DateTime.now().toUtc());
  }

  Future<List<SpriteRestoreItem>> review(SpriteBackup backup) async {
    final current = await repository.list();
    final result = <SpriteRestoreItem>[];
    for (final e in backup.entries) {
      final matches = current.where((a) => a.id == e.id);
      final old = matches.isEmpty ? null : matches.first;
      var status = SpriteRestoreStatus.missing;
      if (old != null) {
        status = SpriteRestoreStatus.conflict;
        if (old.name == e.name &&
            canonicalSpriteManifest(old.atlas) ==
                canonicalSpriteManifest(e.atlas)) {
          final bytes = await fetch(Uri.parse(old.sheetUrl));
          if (sha256.convert(bytes).toString() == e.digest) {
            status = SpriteRestoreStatus.identical;
          }
        }
      }
      result.add(
        SpriteRestoreItem(
          e,
          old,
          status,
          sameName: old == null && current.any((a) => a.name == e.name),
        ),
      );
    }
    return result;
  }

  Future<SpriteRestoreResult> restore(
    List<SpriteRestoreItem> items,
    Map<String, SpriteRestoreChoice> choices, {
    void Function(int, int)? progress,
  }) async {
    // Validate the entire selection before the first write, including direct callers.
    for (final i in items) {
      if ((choices[i.entry.id] ?? i.defaultChoice) !=
          SpriteRestoreChoice.skip) {
        await SpriteBackup.validateEntry(i.entry);
      }
    }
    final result = SpriteRestoreResult();
    var done = 0;
    for (final i in items) {
      final choice = choices[i.entry.id] ?? i.defaultChoice;
      if (choice == SpriteRestoreChoice.skip) {
        result.skipped.add(i.entry.id);
      } else {
        try {
          if (choice == SpriteRestoreChoice.replace && i.current == null ||
              choice == SpriteRestoreChoice.restore && i.current != null) {
            throw StateError('Library changed. Review the backup again.');
          }
          await repository.save(
            id: i.entry.id,
            expectedUpdatedAt: choice == SpriteRestoreChoice.replace
                ? i.current!.updatedAt
                : null,
            restoreMissing: choice == SpriteRestoreChoice.restore,
            name: i.entry.name,
            sheet: i.entry.sheet,
            contentType: i.entry.contentType,
            atlas: i.entry.atlas,
          );
          result.restored.add(i.entry.id);
        } catch (e) {
          result.failed[i.entry.id] = e.toString();
        }
      }
      progress?.call(++done, items.length);
    }
    return result;
  }
}

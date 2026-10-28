import 'dart:convert';
import 'dart:typed_data';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/features/sprites/application/sprite_backup_service.dart';
import 'package:ballwars/features/sprites/data/sprite_atlas_repository.dart';
import 'package:ballwars/features/sprites/domain/sprite_backup.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'sprite_import_screen_test.dart' show imageBytes;

const a = '11111111-1111-1111-1111-111111111111';
const b = '22222222-2222-2222-2222-222222222222';
const c = '33333333-3333-3333-3333-333333333333';
CustomAtlas atlas(String id, {String? name}) => CustomAtlas(
  id: id,
  name: name ?? id,
  sheetUrl: 'https://example.test/$id.png',
  sheetPath: '$id/sheet.png',
  atlas: SpriteImport.grid(sheet: 'optimized.png', width: 16, height: 16),
  updatedAt: DateTime.utc(2026),
);

class BackupRepo implements SpriteAtlasRepository {
  List<CustomAtlas> items = [];
  final List<({String? id, DateTime? revision, bool missing})> writes = [];
  final Set<String> fail = {};
  @override
  Future<List<CustomAtlas>> list() async => items;
  @override
  Future<void> delete(String id) async {}
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
    writes.add((id: id, revision: expectedUpdatedAt, missing: restoreMissing));
    if (fail.contains(id)) throw StateError('network unavailable');
    final value = CustomAtlas(
      id: id!,
      name: name,
      sheetUrl: 'https://example.test/$id/new.png',
      sheetPath: '$id/new.png',
      atlas: atlas,
      updatedAt: DateTime.utc(2026, 10, 28),
    );
    items = [...items.where((i) => i.id != id), value];
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'backup round trip embeds images and preserves IDs and animation metadata without external URLs',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final bytes = await imageBytes(16),
            repo = BackupRepo()..items = [atlas(a, name: 'Kage Bunshin')];
        final backup = await SpriteBackupService(
          repo,
          fetch: (_) async => bytes,
        ).export(repo.items);
        final encoded = backup.encode();
        expect(utf8.decode(encoded), isNot(contains('https://')));
        final restored = await SpriteBackup.decode(encoded);
        expect(restored.entries.single.id, a);
        expect(restored.entries.single.sheet, bytes);
        expect(
          spriteAtlasJson(restored.entries.single.atlas),
          spriteAtlasJson(repo.items.single.atlas),
        );
      });
    },
  );
  test(
    'corruption, duplicate IDs, excessive manifests and unsupported versions are rejected',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final bytes = await imageBytes(16);
        final entry = SpriteBackupEntry(
          id: a,
          name: 'Icon',
          atlas: atlas(a).atlas,
          sheet: bytes,
          contentType: 'image/png',
          updatedAt: DateTime.utc(2026),
        );
        Map<String, dynamic> data() =>
            jsonDecode(
                  utf8.decode(
                    SpriteBackup([entry], DateTime.utc(2026)).encode(),
                  ),
                )
                as Map<String, dynamic>;
        for (final mutation in <void Function(Map<String, dynamic>)>[
          (j) => j['version'] = 99,
          (j) => j['atlases'][0]['sha256'] = 'bad',
          (j) => j['atlases'].add(j['atlases'][0]),
          (j) =>
              j['atlases'][0]['manifest']['sprites']['sprite']['frames'][0][2] =
                  999,
        ]) {
          final j = data();
          mutation(j);
          await expectLater(
            SpriteBackup.decode(utf8.encode(jsonEncode(j))),
            throwsFormatException,
          );
        }
      });
    },
  );
  test(
    'review skips identical and conflicting IDs; missing entry restores with original ID',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final bytes = await imageBytes(16);
        final repo = BackupRepo()..items = [atlas(a), atlas(b), atlas(c)];
        final service = SpriteBackupService(repo, fetch: (_) async => bytes);
        final backup = await service.export(repo.items);
        repo.items = [atlas(a), atlas(b, name: 'Changed')];
        final review = await service.review(backup);
        expect(review.map((i) => i.status), [
          SpriteRestoreStatus.identical,
          SpriteRestoreStatus.conflict,
          SpriteRestoreStatus.missing,
        ]);
        final result = await service.restore(review, {});
        expect(result.skipped, [a, b]);
        expect(result.restored, [c]);
        expect(repo.writes.single.id, c);
        expect(repo.writes.single.missing, isTrue);
        final replacement = await service.restore(
          [review[1]],
          {b: SpriteRestoreChoice.replace},
        );
        expect(replacement.restored, [b]);
        expect(repo.writes.last.revision, review[1].current!.updatedAt);
        expect(repo.writes.last.missing, isFalse);
      });
    },
  );
  test(
    'all selected images validate before any writes; partial failures are reported and retryable',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final bytes = await imageBytes(16), repo = BackupRepo();
        final service = SpriteBackupService(repo, fetch: (_) async => bytes);
        final backup = await service.export([atlas(a), atlas(b)]);
        final review = await service.review(backup);
        final invalid = SpriteBackupEntry(
          id: b,
          name: 'Bad',
          atlas: atlas(b).atlas,
          sheet: Uint8List(4),
          contentType: 'image/png',
          updatedAt: DateTime.utc(2026),
        );
        await expectLater(
          service.restore([
            review.first,
            SpriteRestoreItem(invalid, null, SpriteRestoreStatus.missing),
          ], {}),
          throwsFormatException,
        );
        expect(repo.writes, isEmpty);
        repo.fail.add(b);
        final result = await service.restore(review, {});
        expect(result.restored, [a]);
        expect(result.failed.keys, [b]);
        repo.fail.clear();
        final retry = await service.restore(review, {
          a: SpriteRestoreChoice.skip,
        });
        expect(retry.restored, [b]);
        expect(repo.writes.where((w) => w.id == a), hasLength(1));
      });
    },
  );
}

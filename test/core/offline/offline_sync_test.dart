import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/offline/offline_sync.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';

const _catalog = '''
{"version": 1, "groups": [
 {"id": "shoes", "name": "Shoes", "style": "logo", "balls": [
  {"id": "nike", "name": "Nike", "image": "shoes/nike.svg", "hash": "aaaaaaaaaa", "color": "#111111"},
  {"id": "puma", "name": "Puma", "image": "shoes/puma.svg", "hash": "bbbbbbbbbb", "color": "#242B2F"}]}
]}
''';

BallPackRepository _repo(Future<String> Function(Uri) fetch) =>
    BallPackRepository(baseUri: Uri.parse('https://example.com/packs/'), fetch: fetch);

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());

  test('downloads every pack image once and reports progress', () async {
    final fetched = <String>[];
    Future<Uint8List> fetch(Uri url) async {
      fetched.add(url.toString());
      return Uint8List.fromList([1, 2, 3]);
    }

    final progress = <(int, int)>[];
    await OfflineSync(packs: _repo((_) async => _catalog), fetch: fetch).run(onProgress: (d, t) => progress.add((d, t)));
    expect(fetched, hasLength(2));
    expect(fetched.first, startsWith('https://example.com/packs/shoes/'));
    expect(fetched.first, contains('?v='));
    expect(progress.first, (0, 2));
    expect(progress.last, (2, 2));
    expect(await OfflineStore.instance.read(fetched.first), [1, 2, 3]);

    // Next start: nothing new to download.
    fetched.clear();
    progress.clear();
    await OfflineSync(packs: _repo((_) async => _catalog), fetch: fetch).run(onProgress: (d, t) => progress.add((d, t)));
    expect(fetched, isEmpty);
    expect(progress, [(0, 0)]);
  });

  test('a changed image (new hash) downloads again', () async {
    var count = 0;
    Future<Uint8List> fetch(Uri url) async {
      count++;
      return Uint8List(1);
    }

    await OfflineSync(packs: _repo((_) async => _catalog), fetch: fetch).run();
    await OfflineSync(packs: _repo((_) async => _catalog.replaceFirst('aaaaaaaaaa', 'cccccccccc')), fetch: fetch).run();
    expect(count, 3);
  });

  test('failed downloads are skipped and retried on the next run', () async {
    var fail = true;
    Future<Uint8List> fetch(Uri url) async {
      if (fail) throw Exception('offline');
      return Uint8List(1);
    }

    await OfflineSync(packs: _repo((_) async => _catalog), fetch: fetch).run();
    fail = false;
    final progress = <(int, int)>[];
    await OfflineSync(packs: _repo((_) async => _catalog), fetch: fetch).run(onProgress: (d, t) => progress.add((d, t)));
    expect(progress.last, (2, 2));
  });

  test('offline, the pack catalog comes from the last download', () async {
    await _repo((_) async => _catalog).load();
    final packs = await _repo((_) async => throw Exception('offline')).load();
    expect(packs.single.balls.map((b) => b.name), ['Nike', 'Puma']);
  });

  test('offline with nothing saved yet, the catalog load fails', () async {
    expect(_repo((_) async => throw Exception('offline')).load(), throwsException);
  });
}

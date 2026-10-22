import 'package:flutter/foundation.dart';
import '../../features/ball_management/domain/custom_ball.dart';
import '../../features/ball_packs/data/ball_pack_repository.dart';
import '../../features/custom_groups/data/custom_group_repository.dart';
import '../utils/ball_image_loader.dart';
import 'offline_store.dart';

/// Run at startup: downloads every ball image the Match Setup can show (all
/// packs, the user's own groups and the ones they added) that isn't in
/// [OfflineStore] yet. Afterwards the categories open instantly and the app
/// works offline. Images are keyed by URL, and pack URLs carry a content hash,
/// so only new or changed images download. Failures are skipped; they are
/// tried again on the next start, or when the ball is first shown.
class OfflineSync {
  final BallPackRepository packs;
  final CustomGroupRepository? groups;
  final Future<Uint8List> Function(Uri url) fetch;

  /// Downloads running at once.
  final int parallel;

  OfflineSync({
    required this.packs,
    this.groups,
    Future<Uint8List> Function(Uri url)? fetch,
    this.parallel = 6,
  }) : fetch = fetch ?? BallImageLoader.fetch;

  /// [onProgress] gets (downloaded, to download) as images arrive.
  Future<void> run({void Function(int done, int total)? onProgress}) async {
    final store = OfflineStore.instance;
    final urls = <String>{};
    void add(Iterable<CustomBall> balls) => urls.addAll([
          for (final b in balls)
            if (b.imageUrl != null) b.imageUrl!,
        ]);

    try {
      for (final pack in await packs.load()) {
        add(pack.balls);
      }
    } catch (e) {
      debugPrint('OfflineSync: packs: $e');
    }
    final repo = groups;
    if (repo != null) {
      for (final load in [repo.myGroups, repo.savedGroups]) {
        try {
          for (final group in await load()) {
            add(group.balls);
          }
        } catch (e) {
          debugPrint('OfflineSync: groups: $e');
        }
      }
    }

    final toFetch = await store.missing(urls);
    final missing = toFetch.iterator;
    final total = toFetch.length;
    var done = 0;
    onProgress?.call(0, total);
    Future<void> worker() async {
      while (missing.moveNext()) {
        final url = missing.current;
        try {
          await store.write(url, await fetch(Uri.parse(url)).timeout(const Duration(seconds: 20)));
        } catch (e) {
          debugPrint('OfflineSync: $url: $e');
        }
        onProgress?.call(++done, total);
      }
    }

    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
  }
}
